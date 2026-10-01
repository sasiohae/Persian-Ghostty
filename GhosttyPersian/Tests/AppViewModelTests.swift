import XCTest
@testable import GhosttyPersian

@MainActor
final class AppViewModelTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("AppVMTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temp = tempDirectory, FileManager.default.fileExists(atPath: temp.path) {
            try? FileManager.default.removeItem(at: temp)
        }
        try super.tearDownWithError()
    }

    // 1. Initial loading when configuration exists on disk
    func testLoadConfigurationWhenExists() async throws {
        let configURL = tempDirectory.appendingPathComponent("config.ghostty")
        try "font-family = Monaco\nfont-size = 14\n".write(to: configURL, atomically: true, encoding: .utf8)

        let mockRepo = MockConfigRepository(
            effectivePath: GhosttyConfigPath(url: configURL, scope: .macOS, exists: true, precedenceOrder: 4),
            loadedConfig: LoadedConfiguration(
                path: GhosttyConfigPath(url: configURL, scope: .macOS, exists: true, precedenceOrder: 4),
                document: GhosttyConfigParser().parse("font-family = Monaco\nfont-size = 14\n"),
                rawContent: "font-family = Monaco\nfont-size = 14\n"
            )
        )
        let mockCLI = MockCLIService()

        let vm = AppViewModel(repository: mockRepo, cliService: mockCLI)
        await vm.loadConfiguration()

        XCTAssertTrue(vm.configExists)
        XCTAssertEqual(vm.effectivePath?.url.path, configURL.path)
        XCTAssertEqual(vm.getEffectiveValue(for: "font-family"), "Monaco")
        XCTAssertEqual(vm.getEffectiveValue(for: "font-size"), "14")
        XCTAssertFalse(vm.isDirty)

        if case .loaded = vm.loadingState {
            // Success
        } else {
            XCTFail("Expected .loaded state, got \(vm.loadingState)")
        }
    }

    // 2. Initial loading when no configuration file exists
    func testLoadConfigurationWhenNoneExists() async {
        let mockRepo = MockConfigRepository(effectivePath: nil, loadedConfig: nil)
        let mockCLI = MockCLIService()

        let vm = AppViewModel(repository: mockRepo, cliService: mockCLI)
        await vm.loadConfiguration()

        XCTAssertFalse(vm.configExists)
        XCTAssertNotNil(vm.effectivePath)
        XCTAssertFalse(vm.isDirty)

        if case .notFound = vm.loadingState {
            // Success
        } else {
            XCTFail("Expected .notFound state, got \(vm.loadingState)")
        }
    }

    // 3. In-memory mutation, dirty state tracking, and reset
    func testInMemoryMutationAndDirtyTracking() async {
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

        XCTAssertFalse(vm.isDirty)
        XCTAssertEqual(vm.getEffectiveValue(for: "font-size"), "12")

        // Mutate setting in memory
        vm.updateSetting(key: "font-size", value: "16")
        XCTAssertTrue(vm.isDirty)
        XCTAssertEqual(vm.getEffectiveValue(for: "font-size"), "16")

        // Revert changes
        vm.resetChanges()
        XCTAssertFalse(vm.isDirty)
        XCTAssertEqual(vm.getEffectiveValue(for: "font-size"), "12")
    }

    // 4. Repeated settings mutation and queries
    func testRepeatedSettingsMutation() async {
        let vm = AppViewModel(repository: MockConfigRepository(), cliService: MockCLIService())
        await vm.loadConfiguration()

        vm.setRepeatedSettings(key: "font-family", values: ["Vazirmatn", "JetBrains Mono", "Menlo"])

        XCTAssertTrue(vm.isDirty)
        let values = vm.getAllValues(for: "font-family")
        XCTAssertEqual(values, ["Vazirmatn", "JetBrains Mono", "Menlo"])
        XCTAssertEqual(vm.getEffectiveValue(for: "font-family"), "Menlo")
    }

    // 5. Remove setting
    func testRemoveSetting() async {
        let initialDoc = GhosttyConfigParser().parse("font-size = 14\ntheme = 3024 Night\n")
        let mockRepo = MockConfigRepository(
            effectivePath: nil,
            loadedConfig: LoadedConfiguration(
                path: GhosttyConfigPath(url: tempDirectory, scope: .macOS, exists: true, precedenceOrder: 4),
                document: initialDoc,
                rawContent: "font-size = 14\ntheme = 3024 Night\n"
            )
        )

        let vm = AppViewModel(repository: mockRepo, cliService: MockCLIService())
        await vm.loadConfiguration()

        XCTAssertEqual(vm.getEffectiveValue(for: "font-size"), "14")
        vm.removeSetting(key: "font-size")

        XCTAssertTrue(vm.isDirty)
        XCTAssertNil(vm.getEffectiveValue(for: "font-size"))
        XCTAssertEqual(vm.getEffectiveValue(for: "theme"), "3024 Night")
    }

    // 6. Save coordination via repository
    func testSaveConfigurationSuccess() async {
        let mockRepo = MockConfigRepository()
        let mockCLI = MockCLIService()
        let vm = AppViewModel(repository: mockRepo, cliService: mockCLI)
        await vm.loadConfiguration()

        vm.updateSetting(key: "font-size", value: "18")
        XCTAssertTrue(vm.isDirty)

        let success = await vm.saveConfiguration(createBackup: true, validate: true)
        XCTAssertTrue(success)
        XCTAssertFalse(vm.isDirty)
        XCTAssertTrue(vm.configExists)

        if case .saved(let result) = vm.saveState {
            XCTAssertEqual(result.document.effectiveValue(for: "font-size"), "18")
        } else {
            XCTFail("Expected .saved state, got \(vm.saveState)")
        }
    }

    // 7. Save failure reports error state
    func testSaveConfigurationFailure() async {
        let mockRepo = MockConfigRepository(shouldFailSaveWith: .atomicReplacementFailed(targetURL: tempDirectory, underlyingError: "Disk full"))
        let vm = AppViewModel(repository: mockRepo, cliService: MockCLIService())
        await vm.loadConfiguration()

        vm.updateSetting(key: "font-size", value: "20")
        let success = await vm.saveConfiguration()

        XCTAssertFalse(success)
        XCTAssertTrue(vm.isDirty)

        if case .failed(let err) = vm.saveState {
            XCTAssertTrue(err.contains("Disk full"))
        } else {
            XCTFail("Expected .failed state, got \(vm.saveState)")
        }
    }

    // 8. Validate current in-memory document without saving
    func testValidateCurrentDocument() async {
        let mockCLI = MockCLIService(validationResult: .valid)
        let vm = AppViewModel(repository: MockConfigRepository(), cliService: mockCLI)

        await vm.checkCLIStatus()
        vm.updateSetting(key: "font-family", value: "Monaco")

        let result = await vm.validateCurrentDocument()
        XCTAssertNotNil(result)
        XCTAssertTrue(result?.isValid == true)
        XCTAssertEqual(vm.validationState, .valid)
    }

    // 9. Load fonts and themes asynchronously
    func testLoadFontsAndThemes() async {
        let mockCLI = MockCLIService(
            fonts: [
                GhosttyFontFamily(name: "Vazirmatn", styles: ["Regular", "Bold"]),
                GhosttyFontFamily(name: "Menlo", styles: ["Regular"])
            ],
            themes: [
                GhosttyTheme(name: "3024 Night", origin: "resources"),
                GhosttyTheme(name: "Custom Theme", origin: "config")
            ]
        )
        let vm = AppViewModel(repository: MockConfigRepository(), cliService: mockCLI)

        await vm.loadFonts()
        XCTAssertEqual(vm.fontsState.fonts.count, 2)
        XCTAssertEqual(vm.fontsState.fonts[0].name, "Vazirmatn")

        await vm.loadThemes()
        XCTAssertEqual(vm.themesState.themes.count, 2)
        XCTAssertEqual(vm.themesState.themes[0].name, "3024 Night")
    }

    // 10. CLI availability check
    func testCheckCLIStatus() async {
        let mockCLI = MockCLIService(isInstalled: true, version: "Ghostty 1.3.1")
        let vm = AppViewModel(repository: MockConfigRepository(), cliService: mockCLI)

        await vm.checkCLIStatus()
        XCTAssertTrue(vm.cliStatus.isAvailable)
        XCTAssertEqual(vm.cliStatus.version, "Ghostty 1.3.1")

        let unavailableCLI = MockCLIService(isInstalled: false)
        let unavailableVM = AppViewModel(repository: MockConfigRepository(), cliService: unavailableCLI)

        await unavailableVM.checkCLIStatus()
        XCTAssertFalse(unavailableVM.cliStatus.isAvailable)
    }
}

// MARK: - Test Mocks

private final class MockConfigRepository: GhosttyConfigRepositoryProtocol, @unchecked Sendable {
    var pathResolver: GhosttyConfigPathResolver = GhosttyConfigPathResolver()
    var effectivePath: GhosttyConfigPath?
    var loadedConfig: LoadedConfiguration?
    var shouldFailSaveWith: GhosttyConfigRepositoryError?

    init(
        effectivePath: GhosttyConfigPath? = nil,
        loadedConfig: LoadedConfiguration? = nil,
        shouldFailSaveWith: GhosttyConfigRepositoryError? = nil
    ) {
        self.effectivePath = effectivePath
        self.loadedConfig = loadedConfig
        self.shouldFailSaveWith = shouldFailSaveWith
    }

    func discoverEffectivePath() -> GhosttyConfigPath? {
        effectivePath
    }

    func loadEffectiveConfiguration() throws -> LoadedConfiguration? {
        loadedConfig
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
        if let error = shouldFailSaveWith {
            throw error
        }
        let url = targetURL ?? URL(fileURLWithPath: "/mock/config")
        return SaveResult(
            targetURL: url,
            backupURL: createBackup ? URL(fileURLWithPath: "/mock/backup") : nil,
            validationResult: .valid,
            document: document
        )
    }

    func createBackup(for sourceURL: URL) throws -> GhosttyBackupInfo {
        GhosttyBackupInfo(url: sourceURL, fileName: "mock.backup", creationDate: Date(), sizeInBytes: 100)
    }

    func listBackups() throws -> [GhosttyBackupInfo] {
        []
    }

    func restoreBackup(from backupURL: URL, to targetURL: URL?, validate: Bool) throws -> SaveResult {
        let doc = GhosttyConfigDocument()
        return SaveResult(targetURL: targetURL ?? backupURL, backupURL: nil, validationResult: .valid, document: doc)
    }
}

private final class MockCLIService: GhosttyCLIServiceProtocol, @unchecked Sendable {
    var isInstalled: Bool
    var version: String
    var validationResult: GhosttyValidationResult
    var fonts: [GhosttyFontFamily]
    var themes: [GhosttyTheme]

    init(
        isInstalled: Bool = true,
        version: String = "Ghostty 1.3.1",
        validationResult: GhosttyValidationResult = .valid,
        fonts: [GhosttyFontFamily] = [],
        themes: [GhosttyTheme] = []
    ) {
        self.isInstalled = isInstalled
        self.version = version
        self.validationResult = validationResult
        self.fonts = fonts
        self.themes = themes
    }

    func isGhosttyInstalled() -> Bool { isInstalled }
    func executableURL() throws -> URL { URL(fileURLWithPath: "/Applications/Ghostty.app/Contents/MacOS/ghostty") }
    func validateConfig(at fileURL: URL) throws -> GhosttyValidationResult { validationResult }
    func listFonts() throws -> [GhosttyFontFamily] { fonts }
    func listThemes(colorScheme: GhosttyThemeColorScheme) throws -> [GhosttyTheme] { themes }
    func getDefaultConfigDocument() throws -> GhosttyConfigDocument { GhosttyConfigDocument() }
    func getVersion() throws -> String { version }
}
