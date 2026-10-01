import XCTest
import SwiftUI
@testable import GhosttyPersian

@MainActor
final class AppearanceSettingsTests: XCTestCase {
    // 1. Theme read, write, and removal
    func testThemeReadAndWrite() {
        let vm = AppViewModel()
        XCTAssertEqual(vm.theme, "")

        vm.theme = "3024 Night"
        XCTAssertEqual(vm.theme, "3024 Night")
        XCTAssertTrue(vm.isDirty)
        XCTAssertEqual(vm.getEffectiveValue(for: "theme"), "3024 Night")

        // Clearing removes the key
        vm.theme = ""
        XCTAssertEqual(vm.theme, "")
        XCTAssertNil(vm.getEffectiveValue(for: "theme"))
    }

    // 2. Background opacity read, write, and clamping
    func testBackgroundOpacity() {
        let vm = AppViewModel()
        XCTAssertEqual(vm.backgroundOpacity, 1.0)

        vm.backgroundOpacity = 0.85
        XCTAssertEqual(vm.backgroundOpacity, 0.85)
        XCTAssertEqual(vm.getEffectiveValue(for: "background-opacity"), "0.85")

        // Clamping upper bound
        vm.backgroundOpacity = 1.5
        XCTAssertEqual(vm.backgroundOpacity, 1.0)
        XCTAssertEqual(vm.getEffectiveValue(for: "background-opacity"), "1")

        // Clamping lower bound
        vm.backgroundOpacity = -0.5
        XCTAssertEqual(vm.backgroundOpacity, 0.0)
        XCTAssertEqual(vm.getEffectiveValue(for: "background-opacity"), "0")
    }

    // 3. Background blur style and presets
    func testBackgroundBlur() {
        let vm = AppViewModel()
        XCTAssertEqual(vm.blurStyle, .disabled)
        XCTAssertEqual(vm.backgroundBlur, "false")

        vm.blurStyle = .enabled
        XCTAssertEqual(vm.blurStyle, .enabled)
        XCTAssertEqual(vm.getEffectiveValue(for: "background-blur"), "true")

        vm.blurStyle = .macosGlassRegular
        XCTAssertEqual(vm.blurStyle, .macosGlassRegular)
        XCTAssertEqual(vm.getEffectiveValue(for: "background-blur"), "macos-glass-regular")

        vm.blurStyle = .macosGlassClear
        XCTAssertEqual(vm.blurStyle, .macosGlassClear)
        XCTAssertEqual(vm.getEffectiveValue(for: "background-blur"), "macos-glass-clear")

        vm.blurStyle = .disabled
        XCTAssertEqual(vm.blurStyle, .disabled)
        XCTAssertEqual(vm.getEffectiveValue(for: "background-blur"), "false")
    }

    // 4. Cursor style options
    func testCursorStyle() {
        let vm = AppViewModel()
        XCTAssertEqual(vm.cursorStyle, .block)

        vm.cursorStyle = .bar
        XCTAssertEqual(vm.cursorStyle, .bar)
        XCTAssertEqual(vm.getEffectiveValue(for: "cursor-style"), "bar")

        vm.cursorStyle = .underline
        XCTAssertEqual(vm.cursorStyle, .underline)
        XCTAssertEqual(vm.getEffectiveValue(for: "cursor-style"), "underline")

        vm.cursorStyle = .blockHollow
        XCTAssertEqual(vm.cursorStyle, .blockHollow)
        XCTAssertEqual(vm.getEffectiveValue(for: "cursor-style"), "block_hollow")
    }

    // 5. Cursor blink tri-state
    func testCursorBlink() {
        let vm = AppViewModel()
        XCTAssertNil(vm.cursorBlink)

        vm.cursorBlink = true
        XCTAssertEqual(vm.cursorBlink, true)
        XCTAssertEqual(vm.getEffectiveValue(for: "cursor-style-blink"), "true")

        vm.cursorBlink = false
        XCTAssertEqual(vm.cursorBlink, false)
        XCTAssertEqual(vm.getEffectiveValue(for: "cursor-style-blink"), "false")

        vm.cursorBlink = nil
        XCTAssertNil(vm.cursorBlink)
        XCTAssertNil(vm.getEffectiveValue(for: "cursor-style-blink"))
    }

    // 6. Color overrides
    func testColorOverrides() {
        let vm = AppViewModel()
        XCTAssertEqual(vm.cursorColor, "")
        XCTAssertEqual(vm.customBackground, "")
        XCTAssertEqual(vm.customForeground, "")

        vm.cursorColor = "#ff007c"
        vm.customBackground = "#1a1b26"
        vm.customForeground = "#c0caf5"

        XCTAssertEqual(vm.getEffectiveValue(for: "cursor-color"), "#ff007c")
        XCTAssertEqual(vm.getEffectiveValue(for: "background"), "#1a1b26")
        XCTAssertEqual(vm.getEffectiveValue(for: "foreground"), "#c0caf5")

        // Clearing removes the keys
        vm.cursorColor = ""
        vm.customBackground = ""
        vm.customForeground = ""

        XCTAssertNil(vm.getEffectiveValue(for: "cursor-color"))
        XCTAssertNil(vm.getEffectiveValue(for: "background"))
        XCTAssertNil(vm.getEffectiveValue(for: "foreground"))
    }

    // 7. Non-destructive round-trip preservation
    func testNonDestructivePreservationWithAppearance() async {
        let source = """
        # Custom Appearance header
        custom-plugin = active

        theme = Dracula
        background-opacity = 0.9

        # Footer note
        """
        let doc = GhosttyConfigParser().parse(source)

        let mockRepo = MockRepo(loadedDoc: doc)
        let vm = AppViewModel(repository: mockRepo, cliService: MockCLI())
        await vm.loadConfiguration()

        vm.theme = "Tokyo Night"
        vm.backgroundOpacity = 0.8

        let serialized = vm.currentDocument.serialize()
        XCTAssertTrue(serialized.contains("# Custom Appearance header"))
        XCTAssertTrue(serialized.contains("custom-plugin = active"))
        XCTAssertTrue(serialized.contains("theme = \"Tokyo Night\"") || serialized.contains("theme = Tokyo Night"))
        XCTAssertTrue(serialized.contains("background-opacity = 0.80") || serialized.contains("background-opacity = 0.8"))
        XCTAssertTrue(serialized.contains("# Footer note"))
    }

    // 8. AppearanceSettingsView instantiates and renders
    func testAppearanceSettingsViewInstantiates() {
        let view = AppearanceSettingsView()
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
