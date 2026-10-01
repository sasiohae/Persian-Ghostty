import XCTest
import SwiftUI
@testable import GhosttyPersian

@MainActor
final class GeneralSettingsTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("GeneralSettingsTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temp = tempDirectory, FileManager.default.fileExists(atPath: temp.path) {
            try? FileManager.default.removeItem(at: temp)
        }
        try super.tearDownWithError()
    }

    // 1. Open configuration in Finder when file exists
    func testOpenConfigurationInFinderWhenFileExists() async throws {
        let configFile = tempDirectory.appendingPathComponent("config.ghostty")
        try "font-size = 14\n".write(to: configFile, atomically: true, encoding: .utf8)

        let mockWorkspace = MockWorkspaceOpener()
        let mockRepo = MockConfigRepository(
            effectivePath: GhosttyConfigPath(url: configFile, scope: .macOS, exists: true, precedenceOrder: 4),
            loadedConfig: LoadedConfiguration(
                path: GhosttyConfigPath(url: configFile, scope: .macOS, exists: true, precedenceOrder: 4),
                document: GhosttyConfigParser().parse("font-size = 14\n"),
                rawContent: "font-size = 14\n"
            )
        )
        let vm = AppViewModel(repository: mockRepo, cliService: MockCLIService(), workspaceOpener: mockWorkspace)
        await vm.loadConfiguration()

        vm.openConfigurationInFinder()
        XCTAssertEqual(mockWorkspace.revealedURLs.count, 1)
        XCTAssertEqual(mockWorkspace.revealedURLs.first?.first?.path, configFile.path)
    }

    // 2. Open configuration in Finder when file does not exist reveals parent directory
    func testOpenConfigurationInFinderWhenFileDoesNotExist() async {
        let nonExistentFile = tempDirectory.appendingPathComponent("missing_config.ghostty")
        let mockWorkspace = MockWorkspaceOpener()
        let resolver = GhosttyConfigPathResolver(
            homeDirectory: tempDirectory,
            fileExists: { _ in false }
        )
        let mockRepo = MockConfigRepository(
            effectivePath: GhosttyConfigPath(url: nonExistentFile, scope: .macOS, exists: false, precedenceOrder: 4),
            pathResolver: resolver
        )
        let vm = AppViewModel(repository: mockRepo, cliService: MockCLIService(), workspaceOpener: mockWorkspace)
        await vm.loadConfiguration()

        vm.openConfigurationInFinder()
        XCTAssertEqual(mockWorkspace.revealedURLs.count, 1)
        XCTAssertEqual(
            mockWorkspace.revealedURLs.first?.first?.resolvingSymlinksInPath().path,
            resolver.macOSConfigDirectory.resolvingSymlinksInPath().path
        )
    }

    // 3. Open configuration in external editor
    func testOpenConfigurationInEditor() async throws {
        let configFile = tempDirectory.appendingPathComponent("config.ghostty")
        try "theme = 3024 Night\n".write(to: configFile, atomically: true, encoding: .utf8)

        let mockWorkspace = MockWorkspaceOpener()
        let mockRepo = MockConfigRepository(
            effectivePath: GhosttyConfigPath(url: configFile, scope: .macOS, exists: true, precedenceOrder: 4)
        )
        let vm = AppViewModel(repository: mockRepo, cliService: MockCLIService(), workspaceOpener: mockWorkspace)
        await vm.loadConfiguration()

        let opened = vm.openConfigurationInEditor()
        XCTAssertTrue(opened)
        XCTAssertEqual(mockWorkspace.openedURLs.count, 1)
        XCTAssertEqual(
            mockWorkspace.openedURLs.first?.resolvingSymlinksInPath().path,
            configFile.resolvingSymlinksInPath().path
        )
    }

    // 4. Open configuration in editor fails if file does not exist
    func testOpenConfigurationInEditorFailsWhenMissing() async {
        let missingFile = tempDirectory.appendingPathComponent("missing.ghostty")
        let mockWorkspace = MockWorkspaceOpener()
        let resolver = GhosttyConfigPathResolver(
            homeDirectory: tempDirectory,
            fileExists: { _ in false }
        )
        let mockRepo = MockConfigRepository(
            effectivePath: GhosttyConfigPath(url: missingFile, scope: .macOS, exists: false, precedenceOrder: 4),
            pathResolver: resolver
        )
        let vm = AppViewModel(repository: mockRepo, cliService: MockCLIService(), workspaceOpener: mockWorkspace)
        await vm.loadConfiguration()

        let opened = vm.openConfigurationInEditor()
        XCTAssertFalse(opened)
        XCTAssertTrue(mockWorkspace.openedURLs.isEmpty)
    }

    // 5. Open Ghostty binary in Finder
    func testOpenGhosttyBinaryInFinder() async {
        let binaryURL = URL(fileURLWithPath: "/Applications/Ghostty.app/Contents/MacOS/ghostty")
        let mockWorkspace = MockWorkspaceOpener()
        let mockCLI = MockCLIService(isInstalled: true, version: "Ghostty 1.3.1")
        let vm = AppViewModel(repository: MockConfigRepository(), cliService: mockCLI, workspaceOpener: mockWorkspace)

        await vm.checkCLIStatus()
        vm.openGhosttyBinaryInFinder()

        XCTAssertEqual(mockWorkspace.revealedURLs.count, 1)
        XCTAssertEqual(mockWorkspace.revealedURLs.first?.first?.path, binaryURL.path)
    }

    // 6. Reload configuration re-reads disk and resets dirty state
    func testReloadConfiguration() async {
        let initialDoc = GhosttyConfigParser().parse("font-size = 12\n")
        let mockRepo = MockConfigRepository(
            effectivePath: GhosttyConfigPath(url: tempDirectory, scope: .macOS, exists: true, precedenceOrder: 4),
            loadedConfig: LoadedConfiguration(
                path: GhosttyConfigPath(url: tempDirectory, scope: .macOS, exists: true, precedenceOrder: 4),
                document: initialDoc,
                rawContent: "font-size = 12\n"
            )
        )
        let vm = AppViewModel(repository: mockRepo, cliService: MockCLIService())
        await vm.loadConfiguration()

        vm.updateSetting(key: "font-size", value: "18")
        XCTAssertTrue(vm.isDirty)

        await vm.reloadConfiguration()
        XCTAssertFalse(vm.isDirty)
        XCTAssertEqual(vm.getEffectiveValue(for: "font-size"), "12")
    }

    // 7. Candidate paths listing
    func testCandidatePathsListing() {
        let vm = AppViewModel()
        let candidates = vm.candidatePaths
        XCTAssertEqual(candidates.count, 4)
    }

    // 8. GeneralSettingsView instantiates and renders
    func testGeneralSettingsViewInstantiates() {
        let view = GeneralSettingsView()
        XCTAssertNotNil(view.body)
    }
}

// MARK: - Test Mocks

private final class MockConfigRepository: GhosttyConfigRepositoryProtocol, @unchecked Sendable {
    var pathResolver: GhosttyConfigPathResolver
    var effectivePath: GhosttyConfigPath?
    var loadedConfig: LoadedConfiguration?

    init(
        effectivePath: GhosttyConfigPath? = nil,
        loadedConfig: LoadedConfiguration? = nil,
        pathResolver: GhosttyConfigPathResolver? = nil
    ) {
        self.effectivePath = effectivePath
        self.loadedConfig = loadedConfig
        if let resolver = pathResolver {
            self.pathResolver = resolver
        } else if let eff = effectivePath {
            self.pathResolver = GhosttyConfigPathResolver(homeDirectory: eff.url.deletingLastPathComponent(), fileExists: { _ in eff.exists })
        } else {
            self.pathResolver = GhosttyConfigPathResolver()
        }
    }

    func discoverEffectivePath() -> GhosttyConfigPath? {
        effectivePath
    }

    func loadEffectiveConfiguration() throws -> LoadedConfiguration? {
        if let config = loadedConfig { return config }
        if let eff = effectivePath, eff.exists {
            return LoadedConfiguration(
                path: eff,
                document: GhosttyConfigDocument(),
                rawContent: ""
            )
        }
        return nil
    }

    func readConfiguration(at url: URL) throws -> LoadedConfiguration {
        if let config = loadedConfig { return config }
        throw GhosttyConfigRepositoryError.cannotReadFile(url: url, underlyingError: "Mock not found")
    }

    func saveConfiguration(
        document: GhosttyConfigDocument,
        to targetURL: URL?,
        createBackup: Bool,
        validate: Bool
    ) throws -> SaveResult {
        SaveResult(targetURL: targetURL ?? URL(fileURLWithPath: "/mock"), backupURL: nil, validationResult: .valid, document: document)
    }

    func createBackup(for sourceURL: URL) throws -> GhosttyBackupInfo {
        GhosttyBackupInfo(url: sourceURL, fileName: "b.backup", creationDate: Date(), sizeInBytes: 0)
    }

    func listBackups() throws -> [GhosttyBackupInfo] {
        []
    }

    func restoreBackup(from backupURL: URL, to targetURL: URL?, validate: Bool) throws -> SaveResult {
        SaveResult(targetURL: targetURL ?? backupURL, backupURL: nil, validationResult: .valid, document: GhosttyConfigDocument())
    }
}

private final class MockCLIService: GhosttyCLIServiceProtocol, @unchecked Sendable {
    var isInstalled: Bool
    var version: String

    init(isInstalled: Bool = true, version: String = "Ghostty 1.3.1") {
        self.isInstalled = isInstalled
        self.version = version
    }

    func isGhosttyInstalled() -> Bool { isInstalled }
    func executableURL() throws -> URL { URL(fileURLWithPath: "/Applications/Ghostty.app/Contents/MacOS/ghostty") }
    func validateConfig(at fileURL: URL) throws -> GhosttyValidationResult { .valid }
    func listFonts() throws -> [GhosttyFontFamily] { [] }
    func listThemes(colorScheme: GhosttyThemeColorScheme) throws -> [GhosttyTheme] { [] }
    func getDefaultConfigDocument() throws -> GhosttyConfigDocument { GhosttyConfigDocument() }
    func getVersion() throws -> String { version }
}
