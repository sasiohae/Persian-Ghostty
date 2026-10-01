import XCTest
import SwiftUI
@testable import GhosttyPersian

@MainActor
final class EndToEndPipelineIntegrationTests: XCTestCase {
    private var tempDirectory: URL!
    private var testHomeDirectory: URL!
    private var testBackupDirectory: URL!
    private var testStagingDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let uniqueID = UUID().uuidString
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("E2EIntegrationTests-\(uniqueID)")
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
        cliService: GhosttyCLIServiceProtocol = E2EMockCLIService()
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

    // MARK: - 1. Full Lifecycle Bootstrapping & Resource Discovery

    func testFullLifecycleBootstrappingAndDiscovery() async {
        let mockCLI = E2EMockCLIService(
            version: "Ghostty 1.3.1 (a1b2c3d)",
            fonts: [
                GhosttyFontFamily(name: "JetBrains Mono", styles: ["Regular", "Bold"]),
                GhosttyFontFamily(name: "Vazirmatn", styles: ["Regular", "Medium", "Bold"])
            ],
            themes: [
                GhosttyTheme(name: "Catppuccin Mocha"),
                GhosttyTheme(name: "Solarized Light")
            ]
        )
        let repo = makeRepository(cliService: mockCLI)
        let vm = AppViewModel(repository: repo, cliService: mockCLI)

        // Run full initial bootstrap
        await vm.loadInitialData()

        // 1. CLI status verified
        XCTAssertTrue(vm.cliStatus.isAvailable)
        XCTAssertEqual(vm.cliStatus.version, "Ghostty 1.3.1 (a1b2c3d)")

        // 2. Fonts discovered
        XCTAssertEqual(vm.fontsState.fonts.count, 2)
        XCTAssertTrue(vm.fontsState.fonts.contains { $0.name == "Vazirmatn" })

        // 3. Themes discovered
        XCTAssertEqual(vm.themesState.themes.count, 2)
        XCTAssertTrue(vm.themesState.themes.contains { $0.name == "Catppuccin Mocha" })

        // 4. Initial document loaded (starts clean)
        XCTAssertFalse(vm.isDirty)
    }

    // MARK: - 2. End-to-End Multi-Section Mutation, Diff Tracking & Atomic Persistence

    func testEndToEndMultiSectionMutationDiffAndAtomicPersistence() async throws {
        let repo = makeRepository()
        let configURL = repo.pathResolver.defaultRecommendedPath
        try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let initialContent = """
        # ==========================================
        # User Custom Ghostty Configuration
        # ==========================================
        unmanaged-custom-plugin = active
        custom-secret-key = 12345

        # Standard settings
        font-family = "Monaco"
        font-size = 12
        theme = "OriginalTheme"
        """
        try initialContent.write(to: configURL, atomically: true, encoding: .utf8)

        let vm = AppViewModel(repository: repo, cliService: E2EMockCLIService())
        await vm.checkCLIStatus()
        await vm.loadConfiguration()

        XCTAssertFalse(vm.isDirty)
        XCTAssertEqual(vm.getEffectiveValue(for: "font-size"), "12")

        // 1. Mutate Typography
        vm.fontSize = 15.5
        vm.fontThicken = true
        vm.adjustCellHeight = "15%"

        // 2. Apply Persian Preset
        _ = vm.applyPersianPreset(preset: .standard)

        // 3. Mutate Appearance
        vm.theme = "Catppuccin Mocha"
        vm.backgroundOpacity = 0.92
        vm.backgroundBlur = "true"

        // 4. Mutate Window
        vm.windowPaddingX = 14
        vm.windowPaddingY = 10
        vm.macosTitlebarStyle = .transparent

        // 5. Mutate Shell
        vm.shellCommand = "/bin/zsh"
        vm.workingDirectoryRaw = "~/Projects"

        // Verify in-memory dirty status and breakdown
        XCTAssertTrue(vm.isDirty)
        XCTAssertGreaterThan(vm.configBreakdown.modifiedCount, 0)
        XCTAssertGreaterThan(vm.modifiedCount(for: .typography), 0)
        XCTAssertGreaterThan(vm.modifiedCount(for: .persian), 0)
        XCTAssertGreaterThan(vm.modifiedCount(for: .appearance), 0)
        XCTAssertGreaterThan(vm.modifiedCount(for: .window), 0)
        XCTAssertGreaterThan(vm.modifiedCount(for: .shell), 0)

        // Diff tracking verification
        let changes = vm.pendingDiff.changedEntries
        XCTAssertFalse(changes.isEmpty)
        XCTAssertTrue(changes.contains { $0.key == "font-size" })
        XCTAssertTrue(changes.contains { $0.key == "theme" })
        XCTAssertTrue(changes.contains { $0.key == "command" })

        // 6. Validate configuration with CLI before saving
        let validation = await vm.validateCurrentDocument()
        XCTAssertNotNil(validation)
        XCTAssertTrue(validation?.isValid ?? false)

        // 7. Save configuration (atomic write + backup creation)
        let saveSuccess = await vm.saveConfiguration(createBackup: true, validate: true)
        XCTAssertTrue(saveSuccess)
        XCTAssertFalse(vm.isDirty)

        // Verify disk content
        let savedDiskContent = try String(contentsOf: configURL, encoding: .utf8)

        // Must contain all mutated values
        XCTAssertTrue(savedDiskContent.contains("font-size = 15.5"))
        XCTAssertTrue(savedDiskContent.contains("font-thicken = true"))
        XCTAssertTrue(savedDiskContent.contains("theme = \"Catppuccin Mocha\""))
        XCTAssertTrue(savedDiskContent.contains("background-opacity = 0.92"))
        XCTAssertTrue(savedDiskContent.contains("window-padding-x = 14"))
        XCTAssertTrue(savedDiskContent.contains("command = /bin/zsh"))

        // Must preserve 100% of original unmanaged comments and custom keys!
        XCTAssertTrue(savedDiskContent.contains("# =========================================="))
        XCTAssertTrue(savedDiskContent.contains("# User Custom Ghostty Configuration"))
        XCTAssertTrue(savedDiskContent.contains("unmanaged-custom-plugin = active"))
        XCTAssertTrue(savedDiskContent.contains("custom-secret-key = 12345"))

        // Verify backup was created
        XCTAssertEqual(vm.backups.count, 1)
        let backup = vm.backups[0]
        let backupContent = try String(contentsOf: backup.url, encoding: .utf8)
        XCTAssertEqual(backupContent, initialContent)
    }

    // MARK: - 3. Rollback & Diagnostic Reporting on Validation Failure

    func testRollbackAndDiagnosticReportingOnValidationFailure() async throws {
        let failingCLI = E2EMockCLIServiceFailing(issues: [
            GhosttyValidationIssue(line: 5, message: "unrecognized option 'bogus-key'")
        ])
        let repo = makeRepository(cliService: failingCLI)
        let configURL = repo.pathResolver.defaultRecommendedPath
        try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let initialContent = "font-size = 14\n"
        try initialContent.write(to: configURL, atomically: true, encoding: .utf8)

        let vm = AppViewModel(repository: repo, cliService: failingCLI)
        await vm.loadConfiguration()

        // Mutate with a key that will fail validation
        vm.updateSetting(key: "bogus-key", value: "invalid")
        XCTAssertTrue(vm.isDirty)

        let saveSuccess = await vm.saveConfiguration(createBackup: true, validate: true)
        XCTAssertFalse(saveSuccess)

        // Diagnostic generated
        XCTAssertNotNil(vm.activeDiagnostic)
        XCTAssertEqual(vm.activeDiagnostic?.domain, .validation)
        XCTAssertEqual(vm.activeDiagnostic?.title, "Ghostty CLI Validation Failed")

        // Target file on disk was 100% untouched
        let diskContent = try String(contentsOf: configURL, encoding: .utf8)
        XCTAssertEqual(diskContent, initialContent)

        // Revert in-memory changes
        vm.resetChanges()
        XCTAssertFalse(vm.isDirty)
        XCTAssertEqual(vm.getEffectiveValue(for: "font-size"), "14")
        XCTAssertNil(vm.getEffectiveValue(for: "bogus-key"))
    }

    // MARK: - 4. End-to-End Backup & Restoration Cycle

    func testEndToEndBackupRestorationCycle() async throws {
        let repo = makeRepository()
        let configURL = repo.pathResolver.defaultRecommendedPath
        try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        let v1Content = "font-size = 14\ntheme = \"V1Theme\"\n"
        try v1Content.write(to: configURL, atomically: true, encoding: .utf8)

        let vm = AppViewModel(repository: repo, cliService: E2EMockCLIService())
        await vm.loadConfiguration()

        // Save v2
        vm.updateSetting(key: "theme", value: "V2Theme", isQuoted: true)
        _ = await vm.saveConfiguration(createBackup: true, validate: false)

        XCTAssertEqual(vm.backups.count, 1)
        let v1Backup = vm.backups[0]

        // Verify disk is currently v2
        let currentDisk = try String(contentsOf: configURL, encoding: .utf8)
        XCTAssertTrue(currentDisk.contains("theme = \"V2Theme\""))

        // Restore v1 backup
        let restored = await vm.restoreBackup(v1Backup, validate: false)
        XCTAssertTrue(restored)

        // Verify disk has reverted to v1
        let restoredDisk = try String(contentsOf: configURL, encoding: .utf8)
        XCTAssertTrue(restoredDisk.contains("theme = \"V1Theme\""))
        XCTAssertFalse(restoredDisk.contains("V2Theme"))
    }

    // MARK: - 5. SwiftUI MainView Bootstrap Verification

    func testMainViewBodyInstantiates() {
        let mainView = MainView()
        XCTAssertNotNil(mainView.body)
    }
}

// MARK: - Integration Mocks

private struct E2EMockCLIService: GhosttyCLIServiceProtocol {
    var version: String = "Ghostty 1.3.1"
    var fonts: [GhosttyFontFamily] = []
    var themes: [GhosttyTheme] = []

    func isGhosttyInstalled() -> Bool { true }
    func executableURL() throws -> URL { URL(fileURLWithPath: "/Applications/Ghostty.app/Contents/MacOS/ghostty") }
    func validateConfig(at fileURL: URL) throws -> GhosttyValidationResult { .valid }
    func listFonts() throws -> [GhosttyFontFamily] { fonts }
    func listThemes(colorScheme: GhosttyThemeColorScheme) throws -> [GhosttyTheme] { themes }
    func getDefaultConfigDocument() throws -> GhosttyConfigDocument { GhosttyConfigDocument() }
    func getVersion() throws -> String { version }
}

private struct E2EMockCLIServiceFailing: GhosttyCLIServiceProtocol {
    let issues: [GhosttyValidationIssue]

    func isGhosttyInstalled() -> Bool { true }
    func executableURL() throws -> URL { URL(fileURLWithPath: "/Applications/Ghostty.app/Contents/MacOS/ghostty") }
    func validateConfig(at fileURL: URL) throws -> GhosttyValidationResult {
        GhosttyValidationResult(isValid: false, issues: issues, rawOutput: "validation error")
    }
    func listFonts() throws -> [GhosttyFontFamily] { [] }
    func listThemes(colorScheme: GhosttyThemeColorScheme) throws -> [GhosttyTheme] { [] }
    func getDefaultConfigDocument() throws -> GhosttyConfigDocument { GhosttyConfigDocument() }
    func getVersion() throws -> String { "Ghostty 1.3.1" }
}
