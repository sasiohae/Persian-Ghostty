import Foundation

/// Represents a loaded configuration file with its metadata and parsed document.
public struct LoadedConfiguration: Sendable, Equatable {
    /// The path specification where this configuration was loaded from.
    public let path: GhosttyConfigPath

    /// The parsed non-destructive document.
    public var document: GhosttyConfigDocument

    /// The raw string content of the configuration file.
    public let rawContent: String

    /// The file modification timestamp if available.
    public let lastModifiedDate: Date?

    public init(
        path: GhosttyConfigPath,
        document: GhosttyConfigDocument,
        rawContent: String,
        lastModifiedDate: Date? = nil
    ) {
        self.path = path
        self.document = document
        self.rawContent = rawContent
        self.lastModifiedDate = lastModifiedDate
    }
}

/// Represents the outcome of saving a configuration document.
public struct SaveResult: Sendable, Equatable {
    /// The destination URL where the configuration was saved.
    public let targetURL: URL

    /// The URL of the pre-write backup if one was created.
    public let backupURL: URL?

    /// The validation result if validation was performed.
    public let validationResult: GhosttyValidationResult?

    /// The saved document.
    public let document: GhosttyConfigDocument

    public init(
        targetURL: URL,
        backupURL: URL?,
        validationResult: GhosttyValidationResult?,
        document: GhosttyConfigDocument
    ) {
        self.targetURL = targetURL
        self.backupURL = backupURL
        self.validationResult = validationResult
        self.document = document
    }
}

/// Metadata describing an existing configuration backup.
public struct GhosttyBackupInfo: Sendable, Equatable, Identifiable {
    public var id: String { url.path }

    /// The file URL of the backup.
    public let url: URL

    /// The backup file name.
    public let fileName: String

    /// Timestamp when the backup was created.
    public let creationDate: Date

    /// File size in bytes.
    public let sizeInBytes: Int64

    public init(url: URL, fileName: String, creationDate: Date, sizeInBytes: Int64) {
        self.url = url
        self.fileName = fileName
        self.creationDate = creationDate
        self.sizeInBytes = sizeInBytes
    }

    /// Formatted relative creation date (e.g. "Just now", "2 hours ago").
    public var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: creationDate, relativeTo: Date())
    }
}

/// Errors occurring during repository and file I/O operations.
public enum GhosttyConfigRepositoryError: LocalizedError, Sendable, Equatable {
    /// No existing configuration file was found.
    case configurationNotFound(searchedPaths: [String])

    /// Failed to read configuration from disk.
    case cannotReadFile(url: URL, underlyingError: String)

    /// Failed to create the directory for the target path.
    case directoryCreationFailed(url: URL, underlyingError: String)

    /// Failed to write the staging configuration file.
    case stagingWriteFailed(url: URL, underlyingError: String)

    /// Ghostty validation failed for the staging configuration.
    case validationFailed(issues: [GhosttyValidationIssue], rawOutput: String)

    /// Failed to create a pre-write backup of the original configuration.
    case backupFailed(targetURL: URL, underlyingError: String)

    /// Failed to atomically replace the target configuration file.
    case atomicReplacementFailed(targetURL: URL, underlyingError: String)

    public var errorDescription: String? {
        switch self {
        case .configurationNotFound(let paths):
            return "No Ghostty configuration file was found. Searched: \(paths.joined(separator: ", "))"
        case .cannotReadFile(let url, let underlying):
            return "Failed to read configuration at '\(url.path)': \(underlying)"
        case .directoryCreationFailed(let url, let underlying):
            return "Failed to create directory at '\(url.path)': \(underlying)"
        case .stagingWriteFailed(let url, let underlying):
            return "Failed to write staging configuration at '\(url.path)': \(underlying)"
        case .validationFailed(let issues, _):
            return "Ghostty configuration validation failed with \(issues.count) issue(s)."
        case .backupFailed(let url, let underlying):
            return "Failed to create backup for '\(url.path)': \(underlying)"
        case .atomicReplacementFailed(let url, let underlying):
            return "Failed to atomically replace configuration at '\(url.path)': \(underlying)"
        }
    }
}
