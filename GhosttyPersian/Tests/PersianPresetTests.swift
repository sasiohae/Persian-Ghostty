import XCTest
import SwiftUI
@testable import GhosttyPersian

@MainActor
final class PersianPresetTests: XCTestCase {
    private let service = PersianPresetService()

    // 1. Applying preset on an empty document
    func testApplyStandardPresetToEmptyDocument() {
        var doc = GhosttyConfigDocument()

        let changes = service.apply(preset: .standard, to: &doc)
        XCTAssertFalse(changes.isEmpty)

        // Verify fonts: fallback mode injects Monaco as primary + Vazirmatn fallback
        let fonts = doc.allValues(for: "font-family")
        XCTAssertEqual(fonts.count, 2)
        XCTAssertEqual(fonts[0], "Monaco")
        XCTAssertEqual(fonts[1], "Vazirmatn")

        // Verify metrics
        XCTAssertEqual(doc.effectiveValue(for: "adjust-cell-height"), "15%")
        XCTAssertEqual(doc.effectiveValue(for: "adjust-font-baseline"), "1")
        XCTAssertEqual(doc.effectiveValue(for: "font-thicken"), "true")

        // Verify window padding
        XCTAssertEqual(doc.effectiveValue(for: "window-padding-x"), "10")
        XCTAssertEqual(doc.effectiveValue(for: "window-padding-y"), "8")
        XCTAssertEqual(doc.effectiveValue(for: "window-padding-balance"), "true")

        // Verify cursor & mouse
        XCTAssertEqual(doc.effectiveValue(for: "cursor-style"), "bar")
        XCTAssertEqual(doc.effectiveValue(for: "cursor-style-blink"), "true")
        XCTAssertEqual(doc.effectiveValue(for: "mouse-hide-while-typing"), "true")
    }

    // 2. Applying Full Persian preset (primary font)
    func testApplyFullPersianPreset() {
        var doc = GhosttyConfigParser().parse("font-family = \"JetBrains Mono\"\n")

        service.apply(preset: .fullPersian, to: &doc)

        let fonts = doc.allValues(for: "font-family")
        XCTAssertEqual(fonts.count, 1)
        XCTAssertEqual(fonts[0], "Vazirmatn")
        XCTAssertEqual(doc.effectiveValue(for: "adjust-cell-height"), "15%")
    }

    // 3. Preservation of unmanaged user keys and comments
    func testPreserveCommentsAndUnmanagedKeys() {
        let source = """
        # Custom user configuration
        custom-plugin = enabled
        custom-keybind = ctrl+shift+p=new_split:right

        # Terminal typography
        font-size = 15

        # Footer comment
        """
        var doc = GhosttyConfigParser().parse(source)

        service.apply(preset: .standard, to: &doc)

        let serialized = doc.serialize()
        XCTAssertTrue(serialized.contains("# Custom user configuration"))
        XCTAssertTrue(serialized.contains("custom-plugin = enabled"))
        XCTAssertTrue(serialized.contains("custom-keybind = ctrl+shift+p=new_split:right"))
        XCTAssertTrue(serialized.contains("font-size = 15"))
        XCTAssertTrue(serialized.contains("# Terminal typography"))
        XCTAssertTrue(serialized.contains("# Footer comment"))

        // Also check preset keys applied
        XCTAssertTrue(serialized.contains("adjust-cell-height = 15%"))
        XCTAssertTrue(serialized.contains("window-padding-x = 10"))
    }

    // 4. Idempotency: applying preset twice causes no duplicate or corrupted keys
    func testPresetApplicationIdempotency() {
        var doc = GhosttyConfigParser().parse("""
        font-family = "JetBrains Mono"
        # Initial comment
        """)

        // First application
        service.apply(preset: .standard, to: &doc)
        let firstRun = doc.serialize()

        // Second application
        service.apply(preset: .standard, to: &doc)
        let secondRun = doc.serialize()

        XCTAssertEqual(firstRun, secondRun, "Applying preset twice must be strictly idempotent")

        // Ensure no duplicate font-family or metric keys
        XCTAssertEqual(doc.allValues(for: "font-family").count, 2)
        XCTAssertEqual(doc.allValues(for: "adjust-cell-height").count, 1)
        XCTAssertEqual(doc.allValues(for: "window-padding-x").count, 1)
    }

    // 5. Preset change preview calculation
    func testPresetPreviewChanges() {
        let doc = GhosttyConfigParser().parse("""
        font-family = Monaco
        adjust-cell-height = 15%
        """)

        let preview = service.previewChanges(for: .standard, on: doc)

        // adjust-cell-height is already 15%, so isModified should be false
        let cellHeightItem = preview.first { $0.key == "adjust-cell-height" }
        XCTAssertNotNil(cellHeightItem)
        XCTAssertFalse(cellHeightItem?.isModified ?? true)

        // font-family needs fallback added, so isModified should be true
        let fontItem = preview.first { $0.key == "font-family" }
        XCTAssertNotNil(fontItem)
        XCTAssertTrue(fontItem?.isModified ?? false)
    }

    // 6. AppViewModel integration and revert support
    func testAppViewModelPresetApplicationAndRevert() async {
        let doc = GhosttyConfigParser().parse("font-family = Monaco\nfont-size = 14\n")
        let mockRepo = MockRepo(loadedDoc: doc)
        let vm = AppViewModel(repository: mockRepo, cliService: MockCLI())
        await vm.loadConfiguration()

        XCTAssertFalse(vm.isDirty)

        // Apply preset
        vm.applyPersianPreset(preset: .standard)
        XCTAssertTrue(vm.isDirty)
        XCTAssertEqual(vm.adjustCellHeight, "15%")

        // Revert in-memory changes
        vm.resetChanges()
        XCTAssertFalse(vm.isDirty)
        XCTAssertEqual(vm.adjustCellHeight, "")
        XCTAssertEqual(vm.primaryFontFamily, "Monaco")
    }

    // 7. PersianSettingsView instantiates with preset controls
    func testPersianSettingsViewInstantiates() {
        let view = PersianSettingsView()
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
