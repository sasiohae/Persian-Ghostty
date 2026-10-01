import Foundation

/// Protocol governing configuration file lifecycle operations.
public protocol GhosttyConfigRepositoryProtocol: Sendable {
    /// The resolver responsible for locating configuration candidate paths.
    var pathResolver: GhosttyConfigPathResolver { get }

    /// Discovers the currently effective configuration path according to precedence rules.
    func discoverEffectivePath() -> GhosttyConfigPath?

    /// Reads and parses the currently effective configuration if one exists.
    func loadEffectiveConfiguration() throws -> LoadedConfiguration?

    /// Reads and parses a configuration file from a specific URL.
    func readConfiguration(at url: URL) throws -> LoadedConfiguration

    /// Safely saves a configuration document following the staging, validation, backup, and atomic replacement lifecycle.
    func saveConfiguration(
        document: GhosttyConfigDocument,
        to targetURL: URL?,
        createBackup: Bool,
        validate: Bool
    ) throws -> SaveResult

    /// Creates a timestamped backup of the specified file.
    func createBackup(for sourceURL: URL) throws -> GhosttyBackupInfo

    /// Lists all existing backups, ordered from newest to oldest.
    func listBackups() throws -> [GhosttyBackupInfo]

    /// Restores a configuration from an existing backup file.
    func restoreBackup(from backupURL: URL, to targetURL: URL?, validate: Bool) throws -> SaveResult

    /// Deletes an existing backup file.
    func deleteBackup(at url: URL) throws

    /// Prunes old backups, retaining only the most recent count snapshots.
    func pruneBackups(keepLatest count: Int) throws -> Int
}

extension GhosttyConfigRepositoryProtocol {
    public func deleteBackup(at url: URL) throws {}
    public func pruneBackups(keepLatest count: Int) throws -> Int { 0 }
}

/// Safe, non-destructive configuration repository implementing atomic writes, validation, and backups.
public struct GhosttyConfigRepository: GhosttyConfigRepositoryProtocol, @unchecked Sendable {
    public let pathResolver: GhosttyConfigPathResolver
    public let parser: GhosttyConfigParser
    public let cliService: GhosttyCLIServiceProtocol
    public let backupDirectoryURL: URL
    public let stagingDirectoryURL: URL
    public let fileManager: FileManager

    public init(
        pathResolver: GhosttyConfigPathResolver = GhosttyConfigPathResolver(),
        parser: GhosttyConfigParser = GhosttyConfigParser(),
        cliService: GhosttyCLIServiceProtocol = GhosttyCLIService(),
        backupDirectoryURL: URL? = nil,
        stagingDirectoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.pathResolver = pathResolver
        self.parser = parser
        self.cliService = cliService
        self.fileManager = fileManager

        let homeDir = pathResolver.homeDirectory
        let appSupportDir = homeDir
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("com.persian-ghostty.GhosttyPersian", isDirectory: true)

        self.backupDirectoryURL = backupDirectoryURL ?? appSupportDir.appendingPathComponent("Backups", isDirectory: true)
        self.stagingDirectoryURL = stagingDirectoryURL ?? fileManager.temporaryDirectory.appendingPathComponent("com.persian-ghostty.GhosttyPersian/Staging", isDirectory: true)
    }

    // MARK: - Discovery & Reading

    public func discoverEffectivePath() -> GhosttyConfigPath? {
        pathResolver.effectiveConfigurationPath()
    }

    public func loadEffectiveConfiguration() throws -> LoadedConfiguration? {
        guard let effective = discoverEffectivePath() else {
            return nil
        }
        return try readConfiguration(at: effective.url)
    }

    public func readConfiguration(at url: URL) throws -> LoadedConfiguration {
        guard fileManager.fileExists(atPath: url.path) else {
            throw GhosttyConfigRepositoryError.cannotReadFile(url: url, underlyingError: "File does not exist")
        }

        let rawContent: String
        do {
            rawContent = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw GhosttyConfigRepositoryError.cannotReadFile(url: url, underlyingError: error.localizedDescription)
        }

        let document = parser.parse(rawContent)

        let isMacOSScope = url.path.hasPrefix(pathResolver.macOSConfigDirectory.path)
        let scope: GhosttyConfigScope = isMacOSScope ? .macOS : .xdg

        let configPath = GhosttyConfigPath(
            url: url,
            scope: scope,
            exists: true,
            precedenceOrder: isMacOSScope ? 4 : 2
        )

        let fileAttrs = try? fileManager.attributesOfItem(atPath: url.path)
        let modDate = fileAttrs?[.modificationDate] as? Date

        return LoadedConfiguration(
            path: configPath,
            document: document,
            rawContent: rawContent,
            lastModifiedDate: modDate
        )
    }

    // MARK: - Saving Lifecycle

    public func saveConfiguration(
        document: GhosttyConfigDocument,
        to targetURL: URL? = nil,
        createBackup: Bool = true,
        validate: Bool = true
    ) throws -> SaveResult {
        let destinationURL = targetURL ?? pathResolver.effectiveConfigurationPath()?.url ?? pathResolver.defaultRecommendedPath
        let parentDirectory = destinationURL.deletingLastPathComponent()

        // 1. Ensure target parent directory exists
        do {
            try fileManager.createDirectory(at: parentDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw GhosttyConfigRepositoryError.directoryCreationFailed(url: parentDirectory, underlyingError: error.localizedDescription)
        }

        // 2. Ensure staging directory exists
        do {
            try fileManager.createDirectory(at: stagingDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw GhosttyConfigRepositoryError.directoryCreationFailed(url: stagingDirectoryURL, underlyingError: error.localizedDescription)
        }

        let stagingFileName = ".staging-\(UUID().uuidString).ghostty"
        let stagingURL = stagingDirectoryURL.appendingPathComponent(stagingFileName)

        // 3. Serialize and write staging file
        let serialized = document.serialize()
        do {
            try serialized.write(to: stagingURL, atomically: true, encoding: .utf8)
        } catch {
            throw GhosttyConfigRepositoryError.stagingWriteFailed(url: stagingURL, underlyingError: error.localizedDescription)
        }

        // 4. Capture original file attributes (e.g. permissions) if target exists
        let targetExists = fileManager.fileExists(atPath: destinationURL.path)
        let originalAttributes = targetExists ? (try? fileManager.attributesOfItem(atPath: destinationURL.path)) : nil
        let originalPermissions = originalAttributes?[.posixPermissions]

        if let permissions = originalPermissions {
            try? fileManager.setAttributes([.posixPermissions: permissions], ofItemAtPath: stagingURL.path)
        }

        // 5. Validation using Ghostty CLI (if installed and requested)
        var validationResult: GhosttyValidationResult?
        if validate && cliService.isGhosttyInstalled() {
            do {
                let result = try cliService.validateConfig(at: stagingURL)
                validationResult = result
                if !result.isValid {
                    try? fileManager.removeItem(at: stagingURL)
                    throw GhosttyConfigRepositoryError.validationFailed(issues: result.issues, rawOutput: result.rawOutput)
                }
            } catch let repoError as GhosttyConfigRepositoryError {
                throw repoError
            } catch {
                try? fileManager.removeItem(at: stagingURL)
                throw GhosttyConfigRepositoryError.validationFailed(issues: [], rawOutput: error.localizedDescription)
            }
        }

        // 6. Pre-write backup if target exists and backup requested
        var backupURL: URL?
        if createBackup && targetExists {
            let backupInfo = try self.createBackup(for: destinationURL)
            backupURL = backupInfo.url
        }

        // 7. Atomic file replacement
        do {
            var resultingURL: NSURL?
            try fileManager.replaceItem(
                at: destinationURL,
                withItemAt: stagingURL,
                backupItemName: nil,
                options: [],
                resultingItemURL: &resultingURL
            )

            // Re-apply original POSIX permissions to target
            if let permissions = originalPermissions {
                try? fileManager.setAttributes([.posixPermissions: permissions], ofItemAtPath: destinationURL.path)
            }
        } catch {
            // Clean up staging file on failure
            try? fileManager.removeItem(at: stagingURL)
            throw GhosttyConfigRepositoryError.atomicReplacementFailed(targetURL: destinationURL, underlyingError: error.localizedDescription)
        }

        // 8. Clean up staging file if replace did not automatically remove it
        if fileManager.fileExists(atPath: stagingURL.path) {
            try? fileManager.removeItem(at: stagingURL)
        }

        return SaveResult(
            targetURL: destinationURL,
            backupURL: backupURL,
            validationResult: validationResult,
            document: document
        )
    }

    // MARK: - Backups

    public func createBackup(for sourceURL: URL) throws -> GhosttyBackupInfo {
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw GhosttyConfigRepositoryError.cannotReadFile(url: sourceURL, underlyingError: "Source file does not exist")
        }

        do {
            try fileManager.createDirectory(at: backupDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            throw GhosttyConfigRepositoryError.directoryCreationFailed(url: backupDirectoryURL, underlyingError: error.localizedDescription)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let timestamp = formatter.string(from: Date())
        let shortID = UUID().uuidString.prefix(6)
        let backupFileName = "\(sourceURL.lastPathComponent)-\(timestamp)-\(shortID).backup"
        let destinationBackupURL = backupDirectoryURL.appendingPathComponent(backupFileName)

        let originalAttributes = (try? fileManager.attributesOfItem(atPath: sourceURL.path))
        let permissions = originalAttributes?[.posixPermissions]

        do {
            try fileManager.copyItem(at: sourceURL, to: destinationBackupURL)
            if let permissions = permissions {
                try? fileManager.setAttributes([.posixPermissions: permissions], ofItemAtPath: destinationBackupURL.path)
            }
        } catch {
            throw GhosttyConfigRepositoryError.backupFailed(targetURL: sourceURL, underlyingError: error.localizedDescription)
        }

        let attrs = (try? fileManager.attributesOfItem(atPath: destinationBackupURL.path)) ?? [:]
        let creationDate = attrs[.creationDate] as? Date ?? Date()
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0

        return GhosttyBackupInfo(
            url: destinationBackupURL,
            fileName: backupFileName,
            creationDate: creationDate,
            sizeInBytes: size
        )
    }

    public func listBackups() throws -> [GhosttyBackupInfo] {
        guard fileManager.fileExists(atPath: backupDirectoryURL.path) else {
            return []
        }

        let fileURLs: [URL]
        do {
            fileURLs = try fileManager.contentsOfDirectory(
                at: backupDirectoryURL,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
                options: .skipsHiddenFiles
            )
        } catch {
            return []
        }

        var backups: [GhosttyBackupInfo] = []
        for url in fileURLs {
            let attrs = try? fileManager.attributesOfItem(atPath: url.path)
            let date = attrs?[.creationDate] as? Date ?? Date.distantPast
            let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0

            backups.append(GhosttyBackupInfo(
                url: url,
                fileName: url.lastPathComponent,
                creationDate: date,
                sizeInBytes: size
            ))
        }

        return backups.sorted { $0.creationDate > $1.creationDate }
    }

    public func restoreBackup(from backupURL: URL, to targetURL: URL? = nil, validate: Bool = true) throws -> SaveResult {
        guard fileManager.fileExists(atPath: backupURL.path) else {
            throw GhosttyConfigRepositoryError.cannotReadFile(url: backupURL, underlyingError: "Backup file does not exist")
        }
        let loaded = try readConfiguration(at: backupURL)
        return try saveConfiguration(
            document: loaded.document,
            to: targetURL,
            createBackup: true,
            validate: validate
        )
    }

    public func deleteBackup(at url: URL) throws {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    public func pruneBackups(keepLatest count: Int) throws -> Int {
        let all = try listBackups()
        guard all.count > count else { return 0 }
        let toDelete = all.dropFirst(count)
        var deletedCount = 0
        for backup in toDelete {
            try deleteBackup(at: backup.url)
            deletedCount += 1
        }
        return deletedCount
    }
}
