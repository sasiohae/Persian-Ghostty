import XCTest
@testable import GhosttyPersian

final class GhosttyConfigRepositoryTests: XCTestCase {
    private var tempDirectory: URL!
    private var testHomeDirectory: URL!
    private var testBackupDirectory: URL!
    private var testStagingDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let uniqueID = UUID().uuidString
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("GhosttyRepoTests-\(uniqueID)")
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

    // Helper to construct repository with isolated paths
    private func makeRepository(
        cliService: GhosttyCLIServiceProtocol = MockGhosttyCLIServiceValid()
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

    // 1. Discover and load effective configuration when it exists
    func testLoadEffectiveConfigurationWhenExists() throws {
        let repo = makeRepository()
        let configURL = repo.pathResolver.defaultRecommendedPath
        try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let initialContent = """
        # Custom Ghostty Config
        font-family = "JetBrains Mono"
        font-size = 14
        """
        try initialContent.write(to: configURL, atomically: true, encoding: .utf8)

        let loaded = try repo.loadEffectiveConfiguration()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.path.url.path, configURL.path)
        XCTAssertEqual(loaded?.document.effectiveValue(for: "font-family"), "JetBrains Mono")
        XCTAssertEqual(loaded?.document.effectiveValue(for: "font-size"), "14")
        XCTAssertEqual(loaded?.rawContent, initialContent)
        XCTAssertNotNil(loaded?.lastModifiedDate)
    }

    // 2. Load effective configuration when none exists returns nil
    func testLoadEffectiveConfigurationWhenNoneExists() throws {
        let repo = makeRepository()
        let loaded = try repo.loadEffectiveConfiguration()
        XCTAssertNil(loaded)
    }

    // 3. Read configuration from specific URL
    func testReadConfigurationSpecificURL() throws {
        let repo = makeRepository()
        let customURL = tempDirectory.appendingPathComponent("custom.ghostty")
        let content = "theme = 3024 Night\n"
        try content.write(to: customURL, atomically: true, encoding: .utf8)

        let loaded = try repo.readConfiguration(at: customURL)
        XCTAssertEqual(loaded.path.url.path, customURL.path)
        XCTAssertEqual(loaded.document.effectiveValue(for: "theme"), "3024 Night")
    }

    // 4. Reading non-existent configuration throws error
    func testReadConfigurationNonExistentThrows() {
        let repo = makeRepository()
        let missingURL = tempDirectory.appendingPathComponent("nonexistent.ghostty")

        XCTAssertThrowsError(try repo.readConfiguration(at: missingURL)) { error in
            guard let repoError = error as? GhosttyConfigRepositoryError else {
                XCTFail("Expected GhosttyConfigRepositoryError, got \(error)")
                return
            }
            if case .cannotReadFile(let url, _) = repoError {
                XCTAssertEqual(url.path, missingURL.path)
            } else {
                XCTFail("Expected cannotReadFile, got \(repoError)")
            }
        }
    }

    // 5. Save configuration to a new file (creates directories, atomic write, clean staging)
    func testSaveConfigurationNewFile() throws {
        let repo = makeRepository()
        let targetURL = tempDirectory.appendingPathComponent("newDir/subDir/config.ghostty")

        var doc = GhosttyConfigDocument()
        doc.appendAssignment(key: "font-size", value: "16")

        let result = try repo.saveConfiguration(document: doc, to: targetURL, createBackup: true, validate: true)

        XCTAssertEqual(result.targetURL.path, targetURL.path)
        XCTAssertNil(result.backupURL) // No backup since target didn't exist before
        XCTAssertTrue(FileManager.default.fileExists(atPath: targetURL.path))

        let content = try String(contentsOf: targetURL, encoding: .utf8)
        XCTAssertTrue(content.contains("font-size = 16"))

        // Ensure staging directory has no leftover staging files
        let stagingFiles = try FileManager.default.contentsOfDirectory(atPath: testStagingDirectory.path)
        XCTAssertTrue(stagingFiles.isEmpty)
    }

    // 6. Save configuration to an existing file creates backup
    func testSaveConfigurationExistingFileWithBackup() throws {
        let repo = makeRepository()
        let targetURL = tempDirectory.appendingPathComponent("config.ghostty")
        let originalContent = "font-family = Monaco\n"
        try originalContent.write(to: targetURL, atomically: true, encoding: .utf8)

        var newDoc = GhosttyConfigDocument()
        newDoc.appendAssignment(key: "font-family", value: "Vazirmatn")

        let result = try repo.saveConfiguration(document: newDoc, to: targetURL, createBackup: true, validate: true)

        XCTAssertNotNil(result.backupURL)
        guard let backupURL = result.backupURL else { return }

        // Verify backup exists and has original content
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))
        let backupContent = try String(contentsOf: backupURL, encoding: .utf8)
        XCTAssertEqual(backupContent, originalContent)

        // Verify target file has new content
        let updatedContent = try String(contentsOf: targetURL, encoding: .utf8)
        XCTAssertTrue(updatedContent.contains("font-family = Vazirmatn"))
    }

    // 7. Save configuration with createBackup: false skips backup creation
    func testSaveConfigurationWithoutBackup() throws {
        let repo = makeRepository()
        let targetURL = tempDirectory.appendingPathComponent("config.ghostty")
        try "initial = 1\n".write(to: targetURL, atomically: true, encoding: .utf8)

        var newDoc = GhosttyConfigDocument()
        newDoc.appendAssignment(key: "initial", value: "2")

        let result = try repo.saveConfiguration(document: newDoc, to: targetURL, createBackup: false, validate: true)

        XCTAssertNil(result.backupURL)
        let backups = try repo.listBackups()
        XCTAssertTrue(backups.isEmpty)
    }

    // 8. Save configuration preserves POSIX permissions
    func testSaveConfigurationPreservesPermissions() throws {
        let repo = makeRepository()
        let targetURL = tempDirectory.appendingPathComponent("secure_config.ghostty")
        try "font-size = 12\n".write(to: targetURL, atomically: true, encoding: .utf8)

        // Set 0o600 (read/write by owner only)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: targetURL.path)

        var newDoc = GhosttyConfigDocument()
        newDoc.appendAssignment(key: "font-size", value: "14")

        _ = try repo.saveConfiguration(document: newDoc, to: targetURL, createBackup: false, validate: false)

        let attrs = try FileManager.default.attributesOfItem(atPath: targetURL.path)
        let perms = attrs[.posixPermissions] as? Int
        XCTAssertEqual(perms, 0o600)
    }

    // 9. Save configuration aborts and leaves target untouched when Ghostty validation fails
    func testSaveConfigurationAbortsOnValidationFailure() throws {
        let invalidIssue = GhosttyValidationIssue(
            filePath: "/dummy/staging",
            line: 1,
            key: "invalid_key",
            message: "unknown field"
        )
        let failingCLI = MockGhosttyCLIServiceFailing(issues: [invalidIssue])
        let repo = makeRepository(cliService: failingCLI)

        let targetURL = tempDirectory.appendingPathComponent("target_config.ghostty")
        let originalContent = "# Safe configuration\nfont-size = 13\n"
        try originalContent.write(to: targetURL, atomically: true, encoding: .utf8)

        var badDoc = GhosttyConfigDocument()
        badDoc.appendAssignment(key: "invalid_key", value: "broken")

        XCTAssertThrowsError(
            try repo.saveConfiguration(document: badDoc, to: targetURL, createBackup: true, validate: true)
        ) { error in
            guard let repoError = error as? GhosttyConfigRepositoryError else {
                XCTFail("Expected GhosttyConfigRepositoryError, got \(error)")
                return
            }
            if case .validationFailed(let issues, _) = repoError {
                XCTAssertEqual(issues.count, 1)
                XCTAssertEqual(issues.first?.key, "invalid_key")
            } else {
                XCTFail("Expected validationFailed, got \(repoError)")
            }
        }

        // Target file must be completely UNTOUCHED
        let currentTargetContent = try String(contentsOf: targetURL, encoding: .utf8)
        XCTAssertEqual(currentTargetContent, originalContent)

        // Staging file must be cleaned up
        let stagingFiles = try FileManager.default.contentsOfDirectory(atPath: testStagingDirectory.path)
        XCTAssertTrue(stagingFiles.isEmpty)

        // No backup should have been created
        let backups = try repo.listBackups()
        XCTAssertTrue(backups.isEmpty)
    }

    // 10. List backups sorted newest first
    func testListBackupsSorted() throws {
        let repo = makeRepository()
        let targetURL = tempDirectory.appendingPathComponent("config.ghostty")
        try "version 1\n".write(to: targetURL, atomically: true, encoding: .utf8)

        let b1 = try repo.createBackup(for: targetURL)
        Thread.sleep(forTimeInterval: 1.05) // Ensure distinct second timestamp
        try "version 2\n".write(to: targetURL, atomically: true, encoding: .utf8)
        let b2 = try repo.createBackup(for: targetURL)

        let backups = try repo.listBackups()
        XCTAssertEqual(backups.count, 2)
        XCTAssertEqual(backups[0].fileName, b2.fileName)
        XCTAssertEqual(backups[1].fileName, b1.fileName)
        XCTAssertEqual(backups[0].url.resolvingSymlinksInPath().path, b2.url.resolvingSymlinksInPath().path)
        XCTAssertEqual(backups[1].url.resolvingSymlinksInPath().path, b1.url.resolvingSymlinksInPath().path)
    }

    // 11. Restore backup restores configuration and backs up pre-restoration state
    func testRestoreBackup() throws {
        let repo = makeRepository()
        let targetURL = tempDirectory.appendingPathComponent("config.ghostty")
        try "theme = OriginalTheme\n".write(to: targetURL, atomically: true, encoding: .utf8)

        let backup = try repo.createBackup(for: targetURL)

        // Now modify target
        try "theme = MutatedTheme\n".write(to: targetURL, atomically: true, encoding: .utf8)

        // Restore from backup
        let result = try repo.restoreBackup(from: backup.url, to: targetURL, validate: false)

        XCTAssertEqual(result.targetURL.path, targetURL.path)
        let restoredContent = try String(contentsOf: targetURL, encoding: .utf8)
        XCTAssertTrue(restoredContent.contains("theme = OriginalTheme"))
    }

    // 12. Non-destructive round-trip test: preserves unmanaged settings and formatting on save
    func testPreservesUnmanagedSettingsAndFormattingOnSave() throws {
        let repo = makeRepository()
        let targetURL = tempDirectory.appendingPathComponent("complex.ghostty")

        let originalContent = """
        # Custom Title
        # Author: Test

        font-family = Menlo
        unknown-setting = 12345
          custom-indent = value

        # End of config
        """
        try originalContent.write(to: targetURL, atomically: true, encoding: .utf8)

        var loaded = try repo.readConfiguration(at: targetURL)

        // Mutate only font-size (append or update)
        loaded.document.setValue(key: "font-family", value: "Vazirmatn")

        _ = try repo.saveConfiguration(document: loaded.document, to: targetURL, createBackup: false, validate: false)

        let updatedContent = try String(contentsOf: targetURL, encoding: .utf8)

        // Must preserve all comments and unknown settings
        XCTAssertTrue(updatedContent.contains("# Custom Title"))
        XCTAssertTrue(updatedContent.contains("# Author: Test"))
        XCTAssertTrue(updatedContent.contains("font-family = Vazirmatn"))
        XCTAssertTrue(updatedContent.contains("unknown-setting = 12345"))
        XCTAssertTrue(updatedContent.contains("  custom-indent = value"))
        XCTAssertTrue(updatedContent.contains("# End of config"))
    }
}

// MARK: - Test Mocks

private struct MockGhosttyCLIServiceValid: GhosttyCLIServiceProtocol {
    func isGhosttyInstalled() -> Bool { true }
    func executableURL() throws -> URL { URL(fileURLWithPath: "/mock/ghostty") }
    func validateConfig(at fileURL: URL) throws -> GhosttyValidationResult { .valid }
    func listFonts() throws -> [GhosttyFontFamily] { [] }
    func listThemes(colorScheme: GhosttyThemeColorScheme) throws -> [GhosttyTheme] { [] }
    func getDefaultConfigDocument() throws -> GhosttyConfigDocument { GhosttyConfigDocument() }
    func getVersion() throws -> String { "Ghostty 1.3.1" }
}

private struct MockGhosttyCLIServiceFailing: GhosttyCLIServiceProtocol {
    let issues: [GhosttyValidationIssue]

    func isGhosttyInstalled() -> Bool { true }
    func executableURL() throws -> URL { URL(fileURLWithPath: "/mock/ghostty") }
    func validateConfig(at fileURL: URL) throws -> GhosttyValidationResult {
        GhosttyValidationResult(isValid: false, issues: issues, rawOutput: "validation error")
    }
    func listFonts() throws -> [GhosttyFontFamily] { [] }
    func listThemes(colorScheme: GhosttyThemeColorScheme) throws -> [GhosttyTheme] { [] }
    func getDefaultConfigDocument() throws -> GhosttyConfigDocument { GhosttyConfigDocument() }
    func getVersion() throws -> String { "Ghostty 1.3.1" }
}
