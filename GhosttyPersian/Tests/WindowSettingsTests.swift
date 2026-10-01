import XCTest
import SwiftUI
@testable import GhosttyPersian

@MainActor
final class WindowSettingsTests: XCTestCase {
    // 1. macOS titlebar style reading and mutation
    func testMacOSTitlebarStyle() {
        let vm = AppViewModel()
        XCTAssertEqual(vm.macosTitlebarStyle, .transparent)

        vm.macosTitlebarStyle = .native
        XCTAssertEqual(vm.macosTitlebarStyle, .native)
        XCTAssertEqual(vm.getEffectiveValue(for: "macos-titlebar-style"), "native")

        vm.macosTitlebarStyle = .hidden
        XCTAssertEqual(vm.macosTitlebarStyle, .hidden)
        XCTAssertEqual(vm.getEffectiveValue(for: "macos-titlebar-style"), "hidden")

        vm.macosTitlebarStyle = .tabs
        XCTAssertEqual(vm.macosTitlebarStyle, .tabs)
        XCTAssertEqual(vm.getEffectiveValue(for: "macos-titlebar-style"), "tabs")
    }

    // 2. Window buttons and proxy icon toggles
    func testWindowButtonsAndProxyIcon() {
        let vm = AppViewModel()
        XCTAssertTrue(vm.macosWindowButtons)
        XCTAssertTrue(vm.macosTitlebarProxyIcon)

        vm.macosWindowButtons = false
        XCTAssertFalse(vm.macosWindowButtons)
        XCTAssertEqual(vm.getEffectiveValue(for: "macos-window-buttons"), "hidden")

        vm.macosWindowButtons = true
        XCTAssertTrue(vm.macosWindowButtons)
        XCTAssertEqual(vm.getEffectiveValue(for: "macos-window-buttons"), "visible")

        vm.macosTitlebarProxyIcon = false
        XCTAssertFalse(vm.macosTitlebarProxyIcon)
        XCTAssertEqual(vm.getEffectiveValue(for: "macos-titlebar-proxy-icon"), "hidden")

        vm.macosTitlebarProxyIcon = true
        XCTAssertTrue(vm.macosTitlebarProxyIcon)
        XCTAssertEqual(vm.getEffectiveValue(for: "macos-titlebar-proxy-icon"), "visible")
    }

    // 3. Window padding and balance
    func testWindowPaddingAndBalance() {
        let vm = AppViewModel()
        XCTAssertEqual(vm.windowPaddingX, 2)
        XCTAssertEqual(vm.windowPaddingY, 2)
        XCTAssertFalse(vm.windowPaddingBalance)

        vm.windowPaddingX = 14
        vm.windowPaddingY = 16
        vm.windowPaddingBalance = true

        XCTAssertEqual(vm.windowPaddingX, 14)
        XCTAssertEqual(vm.windowPaddingY, 16)
        XCTAssertTrue(vm.windowPaddingBalance)
        XCTAssertEqual(vm.getEffectiveValue(for: "window-padding-x"), "14")
        XCTAssertEqual(vm.getEffectiveValue(for: "window-padding-y"), "16")
        XCTAssertEqual(vm.getEffectiveValue(for: "window-padding-balance"), "true")

        // Clamping negative padding
        vm.windowPaddingX = -10
        XCTAssertEqual(vm.windowPaddingX, 0)
        XCTAssertEqual(vm.getEffectiveValue(for: "window-padding-x"), "0")
    }

    // 4. Window lifecycle, resize, theme, and fullscreen
    func testWindowLifecycleAndResize() {
        let vm = AppViewModel()
        XCTAssertEqual(vm.windowSaveState, .defaultPolicy)
        XCTAssertFalse(vm.windowStepResize)
        XCTAssertEqual(vm.windowTheme, .auto)
        XCTAssertFalse(vm.macosNonNativeFullscreen)

        vm.windowSaveState = .always
        XCTAssertEqual(vm.windowSaveState, .always)
        XCTAssertEqual(vm.getEffectiveValue(for: "window-save-state"), "always")

        vm.windowSaveState = .never
        XCTAssertEqual(vm.windowSaveState, .never)
        XCTAssertEqual(vm.getEffectiveValue(for: "window-save-state"), "never")

        vm.windowStepResize = true
        XCTAssertTrue(vm.windowStepResize)
        XCTAssertEqual(vm.getEffectiveValue(for: "window-step-resize"), "true")

        vm.windowTheme = .dark
        XCTAssertEqual(vm.windowTheme, .dark)
        XCTAssertEqual(vm.getEffectiveValue(for: "window-theme"), "dark")

        vm.macosNonNativeFullscreen = true
        XCTAssertTrue(vm.macosNonNativeFullscreen)
        XCTAssertEqual(vm.getEffectiveValue(for: "macos-non-native-fullscreen"), "true")
    }

    // 5. Non-destructive round-trip preservation
    func testNonDestructivePreservationWithWindowSettings() async {
        let source = """
        # Custom Window configuration
        unknown-window-plugin = true

        macos-titlebar-style = native
        window-padding-x = 8

        # Footer comment
        """
        let doc = GhosttyConfigParser().parse(source)

        let mockRepo = MockRepo(loadedDoc: doc)
        let vm = AppViewModel(repository: mockRepo, cliService: MockCLI())
        await vm.loadConfiguration()

        vm.macosTitlebarStyle = .transparent
        vm.windowPaddingX = 16
        vm.windowPaddingY = 12

        let serialized = vm.currentDocument.serialize()
        XCTAssertTrue(serialized.contains("# Custom Window configuration"))
        XCTAssertTrue(serialized.contains("unknown-window-plugin = true"))
        XCTAssertTrue(serialized.contains("macos-titlebar-style = transparent"))
        XCTAssertTrue(serialized.contains("window-padding-x = 16"))
        XCTAssertTrue(serialized.contains("window-padding-y = 12"))
        XCTAssertTrue(serialized.contains("# Footer comment"))
    }

    // 6. WindowSettingsView instantiates and renders
    func testWindowSettingsViewInstantiates() {
        let view = WindowSettingsView()
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
        SaveResult(targetURL: targetURL ?? URL(fileURLWithPath: "/test"), backupURL: nil, validationResult: .valid, document: document)
    }

    func createBackup(for sourceURL: URL) throws -> GhosttyBackupInfo {
        GhosttyBackupInfo(url: sourceURL, fileName: "b.bak", creationDate: Date(), sizeInBytes: 0)
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
