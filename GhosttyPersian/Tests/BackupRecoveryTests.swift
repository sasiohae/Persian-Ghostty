import XCTest
import SwiftUI
@testable import GhosttyPersian

@MainActor
final class BackupRecoveryTests: XCTestCase {
    private var tempDirectory: URL!
    private var backupDirectory: URL!
    private var stagingDirectory: URL!
    private var configFileURL: URL!
    private var fileManager: FileManager!

    override func setUp() {
        super.setUp()
        fileManager = FileManager.default
        let base = fileManager.temporaryDirectory.appendingPathComponent("BackupRecoveryTests-\(UUID().uuidString)")
        tempDirectory = base
        backupDirectory = base.appendingPathComponent("Backups")
        stagingDirectory = base.appendingPathComponent("Staging")
        configFileURL = base.appendingPathComponent("config")

        try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: stagingDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let temp = tempDirectory {
            try? fileManager.removeItem(at: temp)
        }
        super.tearDown()
    }

    // 1. Full backup lifecycle: create, list, restore, and prune
    func testFullBackupLifecycle() throws {
        let initialContent = "theme = Dracula\nfont-size = 14\n"
        try initialContent.write(to: configFileURL, atomically: true, encoding: .utf8)

        let repo = GhosttyConfigRepository(
            pathResolver: GhosttyConfigPathResolver(homeDirectory: tempDirectory),
            parser: GhosttyConfigParser(),
            cliService: MockCLIService(isValid: true),
            backupDirectoryURL: backupDirectory,
            stagingDirectoryURL: stagingDirectory,
            fileManager: fileManager
        )

        // Step 1: Create Backup
        let backupInfo = try repo.createBackup(for: configFileURL)
        XCTAssertTrue(fileManager.fileExists(atPath: backupInfo.url.path))
        XCTAssertTrue(backupInfo.fileName.hasSuffix(".backup"))
        XCTAssertGreaterThan(backupInfo.sizeInBytes, 0)
        XCTAssertFalse(backupInfo.relativeTimeString.isEmpty)

        // Step 2: List Backups
        var backups = try repo.listBackups()
        XCTAssertEqual(backups.count, 1)
        XCTAssertEqual(backups[0].fileName, backupInfo.fileName)

        // Step 3: Modify source file and restore
        let modifiedContent = "theme = Solarized\nfont-size = 18\n"
        try modifiedContent.write(to: configFileURL, atomically: true, encoding: .utf8)
        XCTAssertEqual(try String(contentsOf: configFileURL, encoding: .utf8), modifiedContent)

        let restoreResult = try repo.restoreBackup(from: backupInfo.url, to: configFileURL, validate: false)
        XCTAssertEqual(restoreResult.targetURL.path, configFileURL.path)

        let restoredContent = try String(contentsOf: configFileURL, encoding: .utf8)
        XCTAssertTrue(restoredContent.contains("theme = Dracula"))
        XCTAssertTrue(restoredContent.contains("font-size = 14"))

        // Step 4: Prune Backups
        let prunedCount = try repo.pruneBackups(keepLatest: 0)
        XCTAssertGreaterThanOrEqual(prunedCount, 1)
        backups = try repo.listBackups()
        XCTAssertTrue(backups.isEmpty)
    }

    // 2. POSIX permissions preservation through backup and restore cycle
    func testPermissionPreservationThroughBackupAndRestore() throws {
        let content = "theme = Nord\n"
        try content.write(to: configFileURL, atomically: true, encoding: .utf8)

        // Set restrictive permissions: 0o600 (read/write by owner only)
        let expectedPermissions: NSNumber = 0o600
        try fileManager.setAttributes([.posixPermissions: expectedPermissions], ofItemAtPath: configFileURL.path)

        let initialAttrs = try fileManager.attributesOfItem(atPath: configFileURL.path)
        XCTAssertEqual(initialAttrs[.posixPermissions] as? NSNumber, expectedPermissions)

        let repo = GhosttyConfigRepository(
            pathResolver: GhosttyConfigPathResolver(homeDirectory: tempDirectory),
            parser: GhosttyConfigParser(),
            cliService: MockCLIService(isValid: true),
            backupDirectoryURL: backupDirectory,
            stagingDirectoryURL: stagingDirectory,
            fileManager: fileManager
        )

        // Create backup and verify backup has matching permissions
        let backupInfo = try repo.createBackup(for: configFileURL)
        let backupAttrs = try fileManager.attributesOfItem(atPath: backupInfo.url.path)
        XCTAssertEqual(backupAttrs[.posixPermissions] as? NSNumber, expectedPermissions)

        // Modify content and restore
        try "theme = Changed\n".write(to: configFileURL, atomically: true, encoding: .utf8)
        _ = try repo.restoreBackup(from: backupInfo.url, to: configFileURL, validate: false)

        let restoredAttrs = try fileManager.attributesOfItem(atPath: configFileURL.path)
        XCTAssertEqual(restoredAttrs[.posixPermissions] as? NSNumber, expectedPermissions)
    }

    // 3. Abort restore if validation fails: zero data loss guarantee
    func testAbortRestoreIfValidationFails() throws {
        let validOriginalContent = "theme = Dracula\n"
        try validOriginalContent.write(to: configFileURL, atomically: true, encoding: .utf8)

        // Create a corrupt backup file
        let corruptBackupURL = backupDirectory.appendingPathComponent("corrupt.backup")
        let corruptContent = "invalid-key = corrupt-value\n"
        try corruptContent.write(to: corruptBackupURL, atomically: true, encoding: .utf8)

        let repo = GhosttyConfigRepository(
            pathResolver: GhosttyConfigPathResolver(homeDirectory: tempDirectory),
            parser: GhosttyConfigParser(),
            cliService: MockCLIService(isValid: false), // Validation will reject!
            backupDirectoryURL: backupDirectory,
            stagingDirectoryURL: stagingDirectory,
            fileManager: fileManager
        )

        XCTAssertThrowsError(try repo.restoreBackup(from: corruptBackupURL, to: configFileURL, validate: true)) { error in
            guard case GhosttyConfigRepositoryError.validationFailed = error else {
                return XCTFail("Expected validationFailed error, got: \(error)")
            }
        }

        // Verify the original file on disk is completely UNTOUCHED
        let contentOnDisk = try String(contentsOf: configFileURL, encoding: .utf8)
        XCTAssertEqual(contentOnDisk, validOriginalContent)
    }

    // 4. Automated pre-restoration safety snapshot creation
    func testPreRestorationSafetySnapshot() throws {
        let originalContent = "version = 1\n"
        try originalContent.write(to: configFileURL, atomically: true, encoding: .utf8)

        let repo = GhosttyConfigRepository(
            pathResolver: GhosttyConfigPathResolver(homeDirectory: tempDirectory),
            parser: GhosttyConfigParser(),
            cliService: MockCLIService(isValid: true),
            backupDirectoryURL: backupDirectory,
            stagingDirectoryURL: stagingDirectory,
            fileManager: fileManager
        )

        // Create an archive with version 2
        let v2Doc = GhosttyConfigParser().parse("version = 2\n")
        let v2URL = backupDirectory.appendingPathComponent("v2.backup")
        try v2Doc.serialize().write(to: v2URL, atomically: true, encoding: .utf8)

        // Restoring v2 onto v1 should create a safety snapshot of v1
        let result = try repo.restoreBackup(from: v2URL, to: configFileURL, validate: false)
        XCTAssertNotNil(result.backupURL)

        if let snapshotURL = result.backupURL {
            let snapshotContent = try String(contentsOf: snapshotURL, encoding: .utf8)
            XCTAssertTrue(snapshotContent.contains("version = 1"))
        }

        let updatedContent = try String(contentsOf: configFileURL, encoding: .utf8)
        XCTAssertTrue(updatedContent.contains("version = 2"))
    }

    // 5. AppViewModel backup management: manual backup, delete, and prune
    func testAppViewModelBackupManagement() async throws {
        let content = "theme = Dracula\n"

        let repo = GhosttyConfigRepository(
            pathResolver: GhosttyConfigPathResolver(homeDirectory: tempDirectory, environment: [:]),
            parser: GhosttyConfigParser(),
            cliService: MockCLIService(isValid: true),
            backupDirectoryURL: backupDirectory,
            stagingDirectoryURL: stagingDirectory,
            fileManager: fileManager
        )

        let targetConfigURL = repo.pathResolver.defaultRecommendedPath
        try fileManager.createDirectory(at: targetConfigURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try content.write(to: targetConfigURL, atomically: true, encoding: .utf8)

        let vm = AppViewModel(repository: repo, cliService: MockCLIService(isValid: true))
        await vm.loadConfiguration()

        XCTAssertTrue(vm.configExists)

        // Create manual backup
        let manual = vm.createManualBackup()
        XCTAssertNotNil(manual)
        XCTAssertEqual(vm.backups.count, 1)

        // Create second backup
        let manual2 = vm.createManualBackup()
        XCTAssertNotNil(manual2)
        XCTAssertEqual(vm.backups.count, 2)

        // Delete first backup
        if let toDelete = manual {
            vm.deleteBackup(toDelete)
        }
        XCTAssertEqual(vm.backups.count, 1)

        // Prune to 0
        let pruned = vm.pruneBackups(keepLatest: 0)
        XCTAssertEqual(pruned, 1)
        XCTAssertEqual(vm.backups.count, 0)
    }

    // 6. ConfigSectionView instantiates with backup tab
    func testConfigSectionViewInstantiatesWithBackupTab() {
        let view = ConfigSectionView()
        XCTAssertNotNil(view.body)
    }
}

// MARK: - Test Mocks

private final class MockCLIService: GhosttyCLIServiceProtocol, @unchecked Sendable {
    let isValid: Bool

    init(isValid: Bool) {
        self.isValid = isValid
    }

    func isGhosttyInstalled() -> Bool { true }
    func executableURL() throws -> URL { URL(fileURLWithPath: "/test/ghostty") }
    func validateConfig(at fileURL: URL) throws -> GhosttyValidationResult {
        if isValid {
            return .valid
        } else {
            return GhosttyValidationResult(
                isValid: false,
                issues: [GhosttyValidationIssue(line: 1, message: "Mock validation error", rawText: "invalid")],
                rawOutput: "error: invalid config"
            )
        }
    }
    func listFonts() throws -> [GhosttyFontFamily] { [] }
    func listThemes(colorScheme: GhosttyThemeColorScheme) throws -> [GhosttyTheme] { [] }
    func getDefaultConfigDocument() throws -> GhosttyConfigDocument { GhosttyConfigDocument() }
    func getVersion() throws -> String { "Ghostty 1.3.1" }
}
