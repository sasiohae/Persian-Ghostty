import XCTest
@testable import GhosttyPersian

final class AtomicRepositoryStressTests: XCTestCase {
    private var tempDirectory: URL!
    private var testHomeDirectory: URL!
    private var testBackupDirectory: URL!
    private var testStagingDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let uniqueID = UUID().uuidString
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("RepoStressTests-\(uniqueID)")
        testHomeDirectory = tempDirectory.appendingPathComponent("Home", isDirectory: true)
        testBackupDirectory = tempDirectory.appendingPathComponent("Backups", isDirectory: true)
        testStagingDirectory = tempDirectory.appendingPathComponent("Staging", isDirectory: true)

        try FileManager.default.createDirectory(at: testHomeDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: testBackupDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: testStagingDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temp = tempDirectory, FileManager.default.fileExists(atPath: temp.path) {
            try? FileManager.default.removeItem(at: temp)
        }
        try super.tearDownWithError()
    }

    private func makeRepository(
        cliService: GhosttyCLIServiceProtocol = StressMockCLIService()
    ) -> GhosttyConfigRepository {
        let resolver = GhosttyConfigPathResolver(
            homeDirectory: testHomeDirectory,
            environment: [:]
        )
        return GhosttyConfigRepository(
            pathResolver: resolver,
            parser: GhosttyConfigParser(),
            cliService: cliService,
            backupDirectoryURL: testBackupDirectory,
            stagingDirectoryURL: testStagingDirectory,
            fileManager: .default
        )
    }

    // MARK: - 1. Target Unmodified on Validation Failure

    func testTargetRemainsUntouchedWhenValidationFails() throws {
        let failingCLI = StressMockCLIFailing()
        let repo = makeRepository(cliService: failingCLI)

        let targetURL = tempDirectory.appendingPathComponent("production_config.ghostty")
        let originalContent = "font-size = 14\ntheme = \"Dark\"\n"
        try originalContent.write(to: targetURL, atomically: true, encoding: .utf8)

        var mutatedDoc = GhosttyConfigDocument()
        mutatedDoc.appendAssignment(key: "font-size", value: "999_invalid")

        XCTAssertThrowsError(try repo.saveConfiguration(
            document: mutatedDoc,
            to: targetURL,
            createBackup: true,
            validate: true
        )) { error in
            guard let repoError = error as? GhosttyConfigRepositoryError else {
                XCTFail("Expected GhosttyConfigRepositoryError, got \(error)")
                return
            }
            if case .validationFailed = repoError {
                // Expected
            } else {
                XCTFail("Expected validationFailed, got \(repoError)")
            }
        }

        // Target file must be 100% identical to original
        let currentTargetContent = try String(contentsOf: targetURL, encoding: .utf8)
        XCTAssertEqual(currentTargetContent, originalContent)

        // Staging directory should be clean
        let stagingFiles = try FileManager.default.contentsOfDirectory(atPath: testStagingDirectory.path)
        XCTAssertTrue(stagingFiles.isEmpty)
    }

    // MARK: - 2. High-Volume Backup Creation and Pruning

    func testHighVolumeBackupCreationAndPruning() throws {
        let repo = makeRepository()
        let targetURL = tempDirectory.appendingPathComponent("active_config.ghostty")
        try "initial = 1\n".write(to: targetURL, atomically: true, encoding: .utf8)

        // Create 15 backups with distinct timestamps
        var createdBackups: [GhosttyBackupInfo] = []
        for i in 1...15 {
            try "version = \(i)\n".write(to: targetURL, atomically: true, encoding: .utf8)
            let backup = try repo.createBackup(for: targetURL)
            createdBackups.append(backup)
            usleep(15_000) // Small delay to guarantee discrete timestamps
        }

        let allBackups = try repo.listBackups()
        XCTAssertEqual(allBackups.count, 15)

        // Prune down to 5 most recent
        let prunedCount = try repo.pruneBackups(keepLatest: 5)
        XCTAssertEqual(prunedCount, 10)

        let remainingBackups = try repo.listBackups()
        XCTAssertEqual(remainingBackups.count, 5)

        // The remaining 5 backups must exist on disk
        for backup in remainingBackups {
            XCTAssertTrue(FileManager.default.fileExists(atPath: backup.url.path))
        }
    }

    // MARK: - 3. Concurrent Document Mutation & Serialization

    func testConcurrentDocumentMutations() async {
        let parser = GhosttyConfigParser()
        let baseContent = """
        # Base Configuration
        font-family = "JetBrains Mono"
        font-size = 14
        theme = "Original"
        window-padding-x = 10
        """
        let baseDoc = parser.parse(baseContent)

        // Run 50 concurrent mutations and serializations across threads
        await withTaskGroup(of: String.self) { group in
            for i in 1...50 {
                group.addTask {
                    var docCopy = baseDoc
                    docCopy.setValue(key: "font-size", value: "\(10 + (i % 20))")
                    docCopy.setValue(key: "theme", value: "Theme_\(i)")
                    docCopy.setValue(key: "thread-key-\(i)", value: "value-\(i)")
                    return docCopy.serialize()
                }
            }

            var resultsCount = 0
            for await serialized in group {
                XCTAssertTrue(serialized.contains("# Base Configuration"))
                XCTAssertTrue(serialized.contains("font-family = \"JetBrains Mono\""))
                resultsCount += 1
            }
            XCTAssertEqual(resultsCount, 50)
        }
    }

    // MARK: - 4. Corrupted Backup Handling

    func testRestoreCorruptBackupAbortsAndPreservesActiveConfig() throws {
        let failingCLI = StressMockCLIFailing()
        let repo = makeRepository(cliService: failingCLI)

        let targetURL = tempDirectory.appendingPathComponent("live.ghostty")
        let liveContent = "font-size = 14\n"
        try liveContent.write(to: targetURL, atomically: true, encoding: .utf8)

        // Create corrupt backup
        let corruptBackupURL = testBackupDirectory.appendingPathComponent("corrupt.backup")
        try "syntax error unparseable garbage".write(to: corruptBackupURL, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try repo.restoreBackup(from: corruptBackupURL, to: targetURL, validate: true)) { error in
            guard let repoError = error as? GhosttyConfigRepositoryError else {
                XCTFail("Expected GhosttyConfigRepositoryError, got \(error)")
                return
            }
            if case .validationFailed = repoError {
                // Expected
            } else {
                XCTFail("Expected validationFailed, got \(repoError)")
            }
        }

        // Live file was untouched
        let restoredContent = try String(contentsOf: targetURL, encoding: .utf8)
        XCTAssertEqual(restoredContent, liveContent)
    }

    // MARK: - 5. Permission and Staging Failures

    func testSaveThrowsWhenStagingDirectoryIsReadOnly() throws {
        // Set staging directory permissions to read-only 0o400
        try FileManager.default.setAttributes([.posixPermissions: 0o400], ofItemAtPath: testStagingDirectory.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: testStagingDirectory.path)
        }

        let repo = makeRepository()
        let targetURL = tempDirectory.appendingPathComponent("target.ghostty")
        var doc = GhosttyConfigDocument()
        doc.appendAssignment(key: "font-size", value: "14")

        XCTAssertThrowsError(try repo.saveConfiguration(document: doc, to: targetURL, createBackup: false, validate: false)) { error in
            guard let repoError = error as? GhosttyConfigRepositoryError else {
                XCTFail("Expected GhosttyConfigRepositoryError, got \(error)")
                return
            }
            if case .stagingWriteFailed = repoError {
                // Expected
            } else {
                XCTFail("Expected stagingWriteFailed, got \(repoError)")
            }
        }
    }
}

// MARK: - Stress Test Mocks

private struct StressMockCLIService: GhosttyCLIServiceProtocol {
    func isGhosttyInstalled() -> Bool { true }
    func executableURL() throws -> URL { URL(fileURLWithPath: "/bin/echo") }
    func validateConfig(at fileURL: URL) throws -> GhosttyValidationResult { .valid }
    func listFonts() throws -> [GhosttyFontFamily] { [] }
    func listThemes(colorScheme: GhosttyThemeColorScheme) throws -> [GhosttyTheme] { [] }
    func getDefaultConfigDocument() throws -> GhosttyConfigDocument { GhosttyConfigDocument() }
    func getVersion() throws -> String { "Ghostty 1.3.1" }
}

private struct StressMockCLIFailing: GhosttyCLIServiceProtocol {
    func isGhosttyInstalled() -> Bool { true }
    func executableURL() throws -> URL { URL(fileURLWithPath: "/bin/echo") }
    func validateConfig(at fileURL: URL) throws -> GhosttyValidationResult {
        GhosttyValidationResult(
            isValid: false,
            issues: [GhosttyValidationIssue(line: 1, message: "syntax error")],
            rawOutput: "syntax error"
        )
    }
    func listFonts() throws -> [GhosttyFontFamily] { [] }
    func listThemes(colorScheme: GhosttyThemeColorScheme) throws -> [GhosttyTheme] { [] }
    func getDefaultConfigDocument() throws -> GhosttyConfigDocument { GhosttyConfigDocument() }
    func getVersion() throws -> String { "Ghostty 1.3.1" }
}
