import XCTest
import SwiftUI
@testable import GhosttyPersian

@MainActor
final class ConfigSectionTests: XCTestCase {
    // 1. Managed keys classification and categories
    func testManagedKeysClassification() {
        XCTAssertTrue(GhosttyManagedKeys.isManaged(key: "font-family"))
        XCTAssertTrue(GhosttyManagedKeys.isManaged(key: "font-size"))
        XCTAssertTrue(GhosttyManagedKeys.isManaged(key: "theme"))
        XCTAssertTrue(GhosttyManagedKeys.isManaged(key: "background-opacity"))
        XCTAssertTrue(GhosttyManagedKeys.isManaged(key: "macos-titlebar-style"))
        XCTAssertTrue(GhosttyManagedKeys.isManaged(key: "window-padding-x"))
        XCTAssertTrue(GhosttyManagedKeys.isManaged(key: "command"))
        XCTAssertTrue(GhosttyManagedKeys.isManaged(key: "shell-integration"))
        XCTAssertTrue(GhosttyManagedKeys.isManaged(key: "working-directory"))

        // Unmanaged / user custom keys
        XCTAssertFalse(GhosttyManagedKeys.isManaged(key: "keybind"))
        XCTAssertFalse(GhosttyManagedKeys.isManaged(key: "custom-shader"))
        XCTAssertFalse(GhosttyManagedKeys.isManaged(key: "unrecognized-flag"))

        // Categories
        XCTAssertEqual(ManagedKeyCategory.category(for: "font-size"), .typography)
        XCTAssertEqual(ManagedKeyCategory.category(for: "theme"), .appearance)
        XCTAssertEqual(ManagedKeyCategory.category(for: "macos-titlebar-style"), .window)
        XCTAssertEqual(ManagedKeyCategory.category(for: "command"), .shell)
        XCTAssertEqual(ManagedKeyCategory.category(for: "unknown"), .other)
    }

    // 2. Document breakdown analysis
    func testConfigBreakdownAnalysis() async {
        let source = """
        # Header comment
        # Another comment line

        font-size = 14
        theme = Dracula

        custom-shortcut = ctrl+a
        auto-update = check

        # Trailing comment
        """
        let doc = GhosttyConfigParser().parse(source)
        let mockRepo = MockRepo(loadedDoc: doc)
        let vm = AppViewModel(repository: mockRepo, cliService: MockCLI())
        await vm.loadConfiguration()

        let breakdown = vm.configBreakdown
        XCTAssertEqual(breakdown.commentLineCount, 3)
        XCTAssertEqual(breakdown.blankLineCount, 3)
        XCTAssertEqual(breakdown.managedCount, 2) // font-size, theme
        XCTAssertEqual(breakdown.unmanagedCount, 2) // custom-shortcut, auto-update
        XCTAssertEqual(breakdown.modifiedCount, 0)

        // Verify unmanaged items captured accurately
        let unmanagedKeys = breakdown.unmanagedItems.map(\.key)
        XCTAssertTrue(unmanagedKeys.contains("custom-shortcut"))
        XCTAssertTrue(unmanagedKeys.contains("auto-update"))
    }

    // 3. Modified settings detection and diff tracking
    func testModifiedSettingsDetection() async {
        let source = """
        theme = Dracula
        font-size = 14
        """
        let doc = GhosttyConfigParser().parse(source)
        let mockRepo = MockRepo(loadedDoc: doc)
        let vm = AppViewModel(repository: mockRepo, cliService: MockCLI())
        await vm.loadConfiguration()

        XCTAssertEqual(vm.configBreakdown.modifiedCount, 0)

        // Modify a setting
        vm.fontSize = 18

        let breakdown = vm.configBreakdown
        XCTAssertEqual(breakdown.modifiedCount, 1)

        let modifiedItem = breakdown.managedItems.first { $0.key == "font-size" }
        XCTAssertNotNil(modifiedItem)
        XCTAssertTrue(modifiedItem?.isModified == true)
        XCTAssertEqual(modifiedItem?.value, "18")
        XCTAssertEqual(modifiedItem?.originalValue, "14")
    }

    // 4. Revert and remove individual setting helpers
    func testRevertAndRemoveSettingHelpers() async {
        let source = """
        theme = Dracula
        font-size = 14
        """
        let doc = GhosttyConfigParser().parse(source)
        let mockRepo = MockRepo(loadedDoc: doc)
        let vm = AppViewModel(repository: mockRepo, cliService: MockCLI())
        await vm.loadConfiguration()

        vm.fontSize = 22
        XCTAssertEqual(vm.fontSize, 22)
        XCTAssertTrue(vm.isDirty)

        // Revert setting to original
        vm.revertSetting(key: "font-size")
        XCTAssertEqual(vm.fontSize, 14)
        XCTAssertFalse(vm.isDirty)

        // Remove managed setting
        vm.removeManagedSetting(key: "theme")
        XCTAssertEqual(vm.theme, "")
        XCTAssertFalse(vm.currentDocument.contains(key: "theme"))
    }

    // 5. Raw formatted preview lines with syntax and diff info
    func testFormattedPreviewLines() async {
        let source = """
        # Custom title
        theme = Solarized
        unknown-key = test
        """
        let doc = GhosttyConfigParser().parse(source)
        let mockRepo = MockRepo(loadedDoc: doc)
        let vm = AppViewModel(repository: mockRepo, cliService: MockCLI())
        await vm.loadConfiguration()

        vm.theme = "Gruvbox"

        let lines = vm.previewLines
        XCTAssertEqual(lines.count, 3)

        // Line 1: comment
        XCTAssertEqual(lines[0].lineNumber, 1)
        XCTAssertEqual(lines[0].lineType, .comment)
        XCTAssertFalse(lines[0].isModified)

        // Line 2: modified managed assignment
        XCTAssertEqual(lines[1].lineNumber, 2)
        XCTAssertEqual(lines[1].lineType, .managedAssignment(key: "theme", value: "Gruvbox"))
        XCTAssertTrue(lines[1].isModified)

        // Line 3: unmanaged assignment
        XCTAssertEqual(lines[2].lineNumber, 3)
        XCTAssertEqual(lines[2].lineType, .unmanagedAssignment(key: "unknown-key", value: "test"))
        XCTAssertFalse(lines[2].isModified)
    }

    // 6. Backups loading and restore action
    func testBackupsInspectionAndRestoration() async {
        let doc = GhosttyConfigParser().parse("theme = Initial")
        let backupInfo = GhosttyBackupInfo(
            url: URL(fileURLWithPath: "/test/backup.ghostty"),
            fileName: "config-20261001.backup",
            creationDate: Date(),
            sizeInBytes: 256
        )
        let mockRepo = MockRepo(loadedDoc: doc, backupsToReturn: [backupInfo])
        let vm = AppViewModel(repository: mockRepo, cliService: MockCLI())

        vm.loadBackups()
        XCTAssertEqual(vm.backups.count, 1)
        XCTAssertEqual(vm.backups[0].fileName, "config-20261001.backup")
        XCTAssertEqual(vm.backups[0].sizeInBytes, 256)

        let success = await vm.restoreBackup(backupInfo)
        XCTAssertTrue(success)
        XCTAssertEqual(vm.saveState, .saved(SaveResult(
            targetURL: URL(fileURLWithPath: "/test/backup.ghostty"),
            backupURL: nil,
            validationResult: .valid,
            document: GhosttyConfigDocument()
        )))
    }

    // 7. ConfigSectionView instantiates and renders body
    func testConfigSectionViewInstantiates() {
        let view = ConfigSectionView()
        XCTAssertNotNil(view.body)
    }
}

// MARK: - Test Mocks

private final class MockRepo: GhosttyConfigRepositoryProtocol, @unchecked Sendable {
    var pathResolver: GhosttyConfigPathResolver = GhosttyConfigPathResolver()
    var loadedDoc: GhosttyConfigDocument
    var backupsToReturn: [GhosttyBackupInfo]

    init(loadedDoc: GhosttyConfigDocument, backupsToReturn: [GhosttyBackupInfo] = []) {
        self.loadedDoc = loadedDoc
        self.backupsToReturn = backupsToReturn
    }

    func discoverEffectivePath() -> GhosttyConfigPath? {
        GhosttyConfigPath(url: URL(fileURLWithPath: "/test/config"), scope: .macOS, exists: true, precedenceOrder: 4)
    }

    func loadEffectiveConfiguration() throws -> LoadedConfiguration? {
        LoadedConfiguration(
            path: GhosttyConfigPath(url: URL(fileURLWithPath: "/test/config"), scope: .macOS, exists: true, precedenceOrder: 4),
            document: loadedDoc,
            rawContent: loadedDoc.serialize()
        )
    }

    func readConfiguration(at url: URL) throws -> LoadedConfiguration {
        LoadedConfiguration(
            path: GhosttyConfigPath(url: url, scope: .macOS, exists: true, precedenceOrder: 4),
            document: loadedDoc,
            rawContent: loadedDoc.serialize()
        )
    }

    func saveConfiguration(document: GhosttyConfigDocument, to targetURL: URL?, createBackup: Bool, validate: Bool) throws -> SaveResult {
        SaveResult(targetURL: targetURL ?? URL(fileURLWithPath: "/test"), backupURL: nil, validationResult: .valid, document: document)
    }

    func createBackup(for sourceURL: URL) throws -> GhosttyBackupInfo {
        GhosttyBackupInfo(url: sourceURL, fileName: "b.bak", creationDate: Date(), sizeInBytes: 0)
    }

    func listBackups() throws -> [GhosttyBackupInfo] {
        backupsToReturn
    }

    func restoreBackup(from backupURL: URL, to targetURL: URL?, validate: Bool) throws -> SaveResult {
        SaveResult(targetURL: targetURL ?? backupURL, backupURL: nil, validationResult: .valid, document: GhosttyConfigDocument())
    }
}

private final class MockCLI: GhosttyCLIServiceProtocol, @unchecked Sendable {
    func isGhosttyInstalled() -> Bool { true }
    func executableURL() throws -> URL { URL(fileURLWithPath: "/test/ghostty") }
    func validateConfig(at fileURL: URL) throws -> GhosttyValidationResult { .valid }
    func listFonts() throws -> [GhosttyFontFamily] { [] }
    func listThemes(colorScheme: GhosttyThemeColorScheme) throws -> [GhosttyTheme] { [] }
    func getDefaultConfigDocument() throws -> GhosttyConfigDocument { GhosttyConfigDocument() }
    func getVersion() throws -> String { "Ghostty 1.3.1" }
}
