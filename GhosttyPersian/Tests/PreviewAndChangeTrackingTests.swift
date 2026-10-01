import XCTest
import SwiftUI
@testable import GhosttyPersian

@MainActor
final class PreviewAndChangeTrackingTests: XCTestCase {
    // 1. Accurate diff generation across additions, modifications, and removals
    func testDiffGenerationAdditionsModificationsRemovals() {
        let originalSource = """
        theme = Dracula
        font-size = 14
        cursor-style = block
        """
        let originalDoc = GhosttyConfigParser().parse(originalSource)

        let modifiedSource = """
        theme = Solarized
        font-size = 14
        window-padding-x = 12
        """
        let currentDoc = GhosttyConfigParser().parse(modifiedSource)

        let diff = ConfigChangeTracker.computeDiff(original: originalDoc, current: currentDoc)

        XCTAssertTrue(diff.hasChanges)
        XCTAssertEqual(diff.totalChangesCount, 3)
        XCTAssertEqual(diff.modifiedCount, 1) // theme Dracula -> Solarized
        XCTAssertEqual(diff.addedCount, 1)    // window-padding-x added
        XCTAssertEqual(diff.removedCount, 1)  // cursor-style removed
        XCTAssertEqual(diff.untouchedManagedCount, 1) // font-size = 14 untouched

        let modifiedItem = diff.changedEntries.first { $0.key == "theme" }
        XCTAssertNotNil(modifiedItem)
        XCTAssertEqual(modifiedItem?.changeKind, .modified)
        XCTAssertEqual(modifiedItem?.oldValue, "Dracula")
        XCTAssertEqual(modifiedItem?.newValue, "Solarized")

        let addedItem = diff.changedEntries.first { $0.key == "window-padding-x" }
        XCTAssertNotNil(addedItem)
        XCTAssertEqual(addedItem?.changeKind, .added)
        XCTAssertNil(addedItem?.oldValue)
        XCTAssertEqual(addedItem?.newValue, "12")

        let removedItem = diff.changedEntries.first { $0.key == "cursor-style" }
        XCTAssertNotNil(removedItem)
        XCTAssertEqual(removedItem?.changeKind, .removed)
        XCTAssertEqual(removedItem?.oldValue, "block")
        XCTAssertNil(removedItem?.newValue)
    }

    // 2. Verification that unmanaged custom keys and comments are preserved and marked untouched
    func testUnmanagedKeysAndCommentsPreservedUntouched() {
        let source = """
        # Custom user configuration header
        unmanaged-plugin = active
        font-size = 14
        # Custom footer comment
        """
        let originalDoc = GhosttyConfigParser().parse(source)

        // Modify managed key
        var currentDoc = originalDoc
        currentDoc.setValue(key: "font-size", value: "16")

        let diff = ConfigChangeTracker.computeDiff(original: originalDoc, current: currentDoc)

        XCTAssertEqual(diff.modifiedCount, 1)
        XCTAssertEqual(diff.addedCount, 0)
        XCTAssertEqual(diff.removedCount, 0)
        XCTAssertGreaterThanOrEqual(diff.preservedUnmanagedCount, 3) // 2 comments + 1 unmanaged key

        let unmanagedEntry = diff.allEntries.first { $0.key == "unmanaged-plugin" }
        XCTAssertNotNil(unmanagedEntry)
        XCTAssertEqual(unmanagedEntry?.changeKind, .untouched)
        XCTAssertEqual(unmanagedEntry?.category, .unmanaged)
        XCTAssertEqual(unmanagedEntry?.newValue, "active")
    }

    // 3. Individual setting reverts via the change tracker
    func testIndividualSettingReverts() async {
        let source = """
        theme = Dracula
        font-size = 14
        cursor-style = block
        """
        let originalDoc = GhosttyConfigParser().parse(source)
        let mockRepo = MockRepo(loadedDoc: originalDoc)
        let vm = AppViewModel(repository: mockRepo, cliService: MockCLI())
        await vm.loadConfiguration()

        // Apply 3 distinct edits: modify, add, remove
        vm.fontSize = 20
        vm.windowPaddingX = 16
        vm.removeSetting(key: "theme")

        XCTAssertTrue(vm.isDirty)
        let diff = vm.pendingDiff
        XCTAssertEqual(diff.totalChangesCount, 3)

        // 1. Revert the modified font-size
        if let fontEntry = diff.changedEntries.first(where: { $0.key == "font-size" }) {
            vm.revertChange(fontEntry)
        }
        XCTAssertEqual(vm.fontSize, 14)

        // 2. Revert the added window-padding-x
        let diff2 = vm.pendingDiff
        if let padEntry = diff2.changedEntries.first(where: { $0.key == "window-padding-x" }) {
            vm.revertChange(padEntry)
        }
        XCTAssertNil(vm.getEffectiveValue(for: "window-padding-x"))

        // 3. Revert the removed theme
        let diff3 = vm.pendingDiff
        if let themeEntry = diff3.changedEntries.first(where: { $0.key == "theme" }) {
            vm.revertChange(themeEntry)
        }
        XCTAssertEqual(vm.theme, "Dracula")

        // All changes reverted: document is clean again
        XCTAssertFalse(vm.isDirty)
    }

    // 4. Repeated key diff tracking and restoration (font-family)
    func testRepeatedKeyDiffTrackingAndRestoration() async {
        let source = """
        font-family = Monaco
        """
        let originalDoc = GhosttyConfigParser().parse(source)
        let mockRepo = MockRepo(loadedDoc: originalDoc)
        let vm = AppViewModel(repository: mockRepo, cliService: MockCLI())
        await vm.loadConfiguration()

        // Inject Persian fallback
        vm.addFallbackFont("Vazirmatn")
        let diff = vm.pendingDiff

        let fontEntry = diff.changedEntries.first { $0.key == "font-family" }
        XCTAssertNotNil(fontEntry)
        XCTAssertEqual(fontEntry?.changeKind, .modified)
        XCTAssertEqual(fontEntry?.oldValue, "Monaco")
        XCTAssertEqual(fontEntry?.newValue, "Monaco -> Vazirmatn")

        // Revert font-family
        if let entry = fontEntry {
            vm.revertChange(entry)
        }
        XCTAssertEqual(vm.primaryFontFamily, "Monaco")
        XCTAssertTrue(vm.fallbackFontFamilies.isEmpty)
        XCTAssertFalse(vm.isDirty)
    }

    // 5. PendingChangesSheetView instantiates and evaluates body
    func testPendingChangesSheetViewInstantiates() {
        let view = PendingChangesSheetView(isPresented: .constant(true))
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
