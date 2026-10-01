import XCTest
import SwiftUI
@testable import GhosttyPersian

@MainActor
final class TypographySettingsTests: XCTestCase {
    // 1. Primary font family read and write
    func testPrimaryFontFamilyReadAndWrite() {
        let vm = AppViewModel()
        XCTAssertEqual(vm.primaryFontFamily, "Monaco")

        vm.primaryFontFamily = "JetBrains Mono"
        XCTAssertEqual(vm.primaryFontFamily, "JetBrains Mono")
        XCTAssertTrue(vm.isDirty)
        XCTAssertEqual(vm.getEffectiveValue(for: "font-family"), "JetBrains Mono")
    }

    // 2. Fallback fonts read, add, remove, and reorder
    func testFallbackFontsReadAddRemove() {
        let vm = AppViewModel()
        vm.primaryFontFamily = "JetBrains Mono"
        XCTAssertTrue(vm.fallbackFontFamilies.isEmpty)

        vm.addFallbackFont("Vazirmatn")
        vm.addFallbackFont("Fira Code")
        XCTAssertEqual(vm.fallbackFontFamilies, ["Vazirmatn", "Fira Code"])

        // All values for font-family should be ["JetBrains Mono", "Vazirmatn", "Fira Code"]
        let allFamilies = vm.getAllValues(for: "font-family")
        XCTAssertEqual(allFamilies, ["JetBrains Mono", "Vazirmatn", "Fira Code"])

        // Remove fallback at index 0
        vm.removeFallbackFont(at: 0)
        XCTAssertEqual(vm.fallbackFontFamilies, ["Fira Code"])

        // Move fallback
        vm.addFallbackFont("Menlo")
        vm.moveFallbackFonts(from: IndexSet(integer: 1), to: 0)
        XCTAssertEqual(vm.fallbackFontFamilies, ["Menlo", "Fira Code"])
    }

    // 3. Font size read, formatted write, and fractional points
    func testFontSizeReadAndWrite() {
        let vm = AppViewModel()
        XCTAssertEqual(vm.fontSize, 13.0)

        // Fractional point size
        vm.fontSize = 14.5
        XCTAssertEqual(vm.fontSize, 14.5)
        XCTAssertEqual(vm.getEffectiveValue(for: "font-size"), "14.5")

        // Whole point size
        vm.fontSize = 16.0
        XCTAssertEqual(vm.fontSize, 16.0)
        XCTAssertEqual(vm.getEffectiveValue(for: "font-size"), "16")
    }

    // 4. Font thickening and strength clamping
    func testFontThickenAndStrength() {
        let vm = AppViewModel()
        XCTAssertFalse(vm.fontThicken)
        XCTAssertEqual(vm.fontThickenStrength, 255)

        vm.fontThicken = true
        XCTAssertTrue(vm.fontThicken)
        XCTAssertEqual(vm.getEffectiveValue(for: "font-thicken"), "true")

        vm.fontThickenStrength = 180
        XCTAssertEqual(vm.fontThickenStrength, 180)
        XCTAssertEqual(vm.getEffectiveValue(for: "font-thicken-strength"), "180")

        // Clamping upper and lower bounds
        vm.fontThickenStrength = 500
        XCTAssertEqual(vm.fontThickenStrength, 255)

        vm.fontThickenStrength = -50
        XCTAssertEqual(vm.fontThickenStrength, 0)
    }

    // 5. Programming ligatures toggle
    func testLigaturesToggle() {
        let vm = AppViewModel()
        XCTAssertTrue(vm.ligaturesEnabled)

        // Disable ligatures -> adds font-feature = -calt
        vm.ligaturesEnabled = false
        XCTAssertFalse(vm.ligaturesEnabled)
        XCTAssertEqual(vm.getEffectiveValue(for: "font-feature"), "-calt")

        // Enable ligatures -> removes -calt
        vm.ligaturesEnabled = true
        XCTAssertTrue(vm.ligaturesEnabled)
        XCTAssertNil(vm.getEffectiveValue(for: "font-feature"))
    }

    // 6. Cell dimensions adjustments
    func testCellDimensionsAdjustments() {
        let vm = AppViewModel()
        XCTAssertEqual(vm.adjustCellWidth, "")
        XCTAssertEqual(vm.adjustCellHeight, "")
        XCTAssertEqual(vm.adjustFontBaseline, "")

        vm.adjustCellWidth = "5%"
        vm.adjustCellHeight = "2"
        vm.adjustFontBaseline = "-1"

        XCTAssertEqual(vm.getEffectiveValue(for: "adjust-cell-width"), "5%")
        XCTAssertEqual(vm.getEffectiveValue(for: "adjust-cell-height"), "2")
        XCTAssertEqual(vm.getEffectiveValue(for: "adjust-font-baseline"), "-1")

        // Clearing removes the keys
        vm.adjustCellWidth = ""
        vm.adjustCellHeight = ""
        vm.adjustFontBaseline = ""

        XCTAssertNil(vm.getEffectiveValue(for: "adjust-cell-width"))
        XCTAssertNil(vm.getEffectiveValue(for: "adjust-cell-height"))
        XCTAssertNil(vm.getEffectiveValue(for: "adjust-font-baseline"))
    }

    // 7. Non-destructive round-trip preservation with typography changes
    func testNonDestructivePreservation() async {
        let parser = GhosttyConfigParser()
        let source = """
        # Custom header comment
        # User special setting
        unknown-theme-plugin = true

        font-family = Monaco
        font-size = 12

        # Footer comment
        """
        let doc = parser.parse(source)

        let mockRepo = MockRepo(loadedDoc: doc)
        let vm = AppViewModel(repository: mockRepo, cliService: MockCLI())

        await vm.loadConfiguration()

        vm.fontSize = 15
        vm.primaryFontFamily = "JetBrains Mono"

        let serialized = vm.currentDocument.serialize()

        // Comments, unknown keys, and structure must remain intact
        XCTAssertTrue(serialized.contains("# Custom header comment"))
        XCTAssertTrue(serialized.contains("# User special setting"))
        XCTAssertTrue(serialized.contains("unknown-theme-plugin = true"))
        XCTAssertTrue(serialized.contains("font-family = \"JetBrains Mono\"") || serialized.contains("font-family = JetBrains Mono"))
        XCTAssertTrue(serialized.contains("font-size = 15"))
        XCTAssertTrue(serialized.contains("# Footer comment"))
    }

    // 8. TypographySettingsView instantiates and renders
    func testTypographySettingsViewInstantiates() {
        let view = TypographySettingsView()
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
