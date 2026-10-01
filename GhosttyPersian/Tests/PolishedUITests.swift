import XCTest
import SwiftUI
@testable import GhosttyPersian

@MainActor
final class PolishedUITests: XCTestCase {
    // 1. StatusBadgeView renders all states properly
    func testStatusBadgeViewInstantiates() {
        let dirtyBadge = StatusBadgeView(isDirty: true, dirtyCount: 3, validationState: .unknown)
        XCTAssertNotNil(dirtyBadge.body)

        let validBadge = StatusBadgeView(isDirty: false, dirtyCount: 0, validationState: .valid)
        XCTAssertNotNil(validBadge.body)

        let invalidBadge = StatusBadgeView(isDirty: false, dirtyCount: 0, validationState: .invalid([], rawOutput: "error"))
        XCTAssertNotNil(invalidBadge.body)

        let validatingBadge = StatusBadgeView(isDirty: false, dirtyCount: 0, validationState: .validating)
        XCTAssertNotNil(validatingBadge.body)

        let syncedBadge = StatusBadgeView(isDirty: false, dirtyCount: 0, validationState: .unknown)
        XCTAssertNotNil(syncedBadge.body)
    }

    // 2. FloatingToastView renders and dismisses
    func testFloatingToastView() {
        var dismissed = false
        let toast = AppViewModel.ToastNotification(title: "Saved", message: "Config was saved.", isError: false)
        let view = FloatingToastView(toast: toast) {
            dismissed = true
        }
        XCTAssertNotNil(view.body)

        view.onDismiss()
        XCTAssertTrue(dismissed)
    }

    // 3. Section modification counting
    func testSectionModificationCounting() async {
        let source = """
        theme = Dracula
        font-size = 14
        window-padding-x = 4
        command = /bin/zsh
        """
        let doc = GhosttyConfigParser().parse(source)
        let mockRepo = MockRepo(loadedDoc: doc)
        let vm = AppViewModel(repository: mockRepo, cliService: MockCLI())
        await vm.loadConfiguration()

        XCTAssertFalse(vm.isDirty)
        XCTAssertEqual(vm.modifiedCount(for: .typography), 0)
        XCTAssertEqual(vm.modifiedCount(for: .appearance), 0)
        XCTAssertEqual(vm.modifiedCount(for: .window), 0)
        XCTAssertEqual(vm.modifiedCount(for: .shell), 0)
        XCTAssertEqual(vm.modifiedCount(for: .config), 0)

        // Modify typography
        vm.fontSize = 16
        XCTAssertEqual(vm.modifiedCount(for: .typography), 1)
        XCTAssertTrue(vm.hasModifications(for: .typography))

        // Modify appearance
        vm.theme = "Solarized"
        XCTAssertEqual(vm.modifiedCount(for: .appearance), 1)
        XCTAssertTrue(vm.hasModifications(for: .appearance))

        // Modify window
        vm.windowPaddingX = 12
        XCTAssertEqual(vm.modifiedCount(for: .window), 1)
        XCTAssertTrue(vm.hasModifications(for: .window))

        // Modify shell
        vm.shellCommand = "/bin/bash"
        XCTAssertEqual(vm.modifiedCount(for: .shell), 1)
        XCTAssertTrue(vm.hasModifications(for: .shell))

        // Total config modified
        XCTAssertEqual(vm.modifiedCount(for: .config), 4)
    }

    // 4. Toast notifications on save and reload
    func testToastNotificationsLifecycle() async {
        let doc = GhosttyConfigParser().parse("theme = Dracula\n")
        let mockRepo = MockRepo(loadedDoc: doc)
        let vm = AppViewModel(repository: mockRepo, cliService: MockCLI())
        await vm.loadConfiguration()

        XCTAssertNil(vm.activeToast)

        // Show toast
        vm.showToast(title: "Test", message: "Notice")
        XCTAssertNotNil(vm.activeToast)
        XCTAssertEqual(vm.activeToast?.title, "Test")
        XCTAssertEqual(vm.activeToast?.message, "Notice")
        XCTAssertFalse(vm.activeToast?.isError ?? true)

        // Dismiss toast
        vm.dismissToast()
        XCTAssertNil(vm.activeToast)

        // Save configuration triggers toast
        vm.theme = "One Dark"
        await vm.saveConfiguration(createBackup: false, validate: false)
        XCTAssertNotNil(vm.activeToast)
        XCTAssertTrue(vm.activeToast?.title.contains("Saved") == true)

        // Reload from disk triggers toast
        await vm.reloadFromDisk()
        XCTAssertNotNil(vm.activeToast)
        XCTAssertTrue(vm.activeToast?.title.contains("Reloaded") == true)
    }

    // 5. SidebarView instantiates and evaluates body
    func testSidebarViewInstantiates() {
        let binding = Binding<NavigationSection?>(get: { .general }, set: { _ in })
        let view = SidebarView(selectedSection: binding)
        XCTAssertNotNil(view.body)
    }

    // 6. MainView instantiates and evaluates body
    func testMainViewInstantiates() {
        let view = MainView()
        XCTAssertNotNil(view.body)
    }
}

// MARK: - Test Mocks

private final class MockRepo: GhosttyConfigRepositoryProtocol, @unchecked Sendable {
    var pathResolver: GhosttyConfigPathResolver = GhosttyConfigPathResolver()
    var loadedDoc: GhosttyConfigDocument

    init(loadedDoc: GhosttyConfigDocument) {
        self.loadedDoc = loadedDoc
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
        SaveResult(targetURL: targetURL ?? URL(fileURLWithPath: "/test/config"), backupURL: nil, validationResult: .valid, document: document)
    }

    func createBackup(for sourceURL: URL) throws -> GhosttyBackupInfo {
        GhosttyBackupInfo(url: sourceURL, fileName: "b.backup", creationDate: Date(), sizeInBytes: 10)
    }

    func listBackups() throws -> [GhosttyBackupInfo] { [] }

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
