import XCTest
@testable import GhosttyPersian

final class GhosttyCLIServiceTests: XCTestCase {
    private let dummyExecutable = URL(fileURLWithPath: "/Applications/Ghostty.app/Contents/MacOS/ghostty")

    // 1. Service discovers executable or throws when missing
    func testExecutableDiscovery() throws {
        let locatorFound = GhosttyExecutableLocator(
            customPath: dummyExecutable,
            environment: [:],
            isExecutableFile: { _ in true }
        )
        let service = GhosttyCLIService(locator: locatorFound, processRunner: MockProcessRunner())
        XCTAssertTrue(service.isGhosttyInstalled())
        XCTAssertEqual(try service.executableURL(), dummyExecutable)

        let locatorMissing = GhosttyExecutableLocator(
            customPath: nil,
            environment: [:],
            isExecutableFile: { _ in false }
        )
        let missingService = GhosttyCLIService(locator: locatorMissing, processRunner: MockProcessRunner())
        XCTAssertFalse(missingService.isGhosttyInstalled())
        XCTAssertThrowsError(try missingService.executableURL()) { error in
            guard let cliError = error as? GhosttyCLIError else {
                XCTFail("Expected GhosttyCLIError, got \(error)")
                return
            }
            if case .executableNotFound = cliError {
                // Expected
            } else {
                XCTFail("Expected executableNotFound, got \(cliError)")
            }
        }
    }

    // 2. Validate configuration with valid output
    func testValidateConfigValid() throws {
        let runner = MockProcessRunner { invocation in
            XCTAssertEqual(invocation.arguments[0], "+validate-config")
            return ProcessOutput(exitCode: 0, standardOutput: "", standardError: "")
        }

        let service = GhosttyCLIService(
            locator: GhosttyExecutableLocator(customPath: dummyExecutable, isExecutableFile: { _ in true }),
            processRunner: runner,
            fileExists: { _ in true }
        )

        let configURL = URL(fileURLWithPath: "/tmp/valid.ghostty")
        let result = try service.validateConfig(at: configURL)

        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(result.rawOutput, "")
    }

    // 3. Validate configuration with line-specific errors
    func testValidateConfigLineSpecificErrors() throws {
        let errorOutput = """
        /tmp/test.ghostty:1:font-size: invalid value "notanumber"
        /tmp/test.ghostty:4:unknown_key: unknown field
        """

        let runner = MockProcessRunner { _ in
            ProcessOutput(exitCode: 1, standardOutput: "", standardError: errorOutput)
        }

        let service = GhosttyCLIService(
            locator: GhosttyExecutableLocator(customPath: dummyExecutable, isExecutableFile: { _ in true }),
            processRunner: runner,
            fileExists: { _ in true }
        )

        let configURL = URL(fileURLWithPath: "/tmp/test.ghostty")
        let result = try service.validateConfig(at: configURL)

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.issues.count, 2)

        XCTAssertEqual(result.issues[0].filePath, "/tmp/test.ghostty")
        XCTAssertEqual(result.issues[0].line, 1)
        XCTAssertEqual(result.issues[0].key, "font-size")
        XCTAssertEqual(result.issues[0].message, "invalid value \"notanumber\"")

        XCTAssertEqual(result.issues[1].filePath, "/tmp/test.ghostty")
        XCTAssertEqual(result.issues[1].line, 4)
        XCTAssertEqual(result.issues[1].key, "unknown_key")
        XCTAssertEqual(result.issues[1].message, "unknown field")
    }

    // 4. Validate configuration with diagnostic errors (e.g. missing theme)
    func testValidateConfigDiagnosticError() throws {
        let errorOutput = """
        theme "NonExistent" not found, tried path "/path/themes/NonExistent"
        """

        let runner = MockProcessRunner { _ in
            ProcessOutput(exitCode: 1, standardOutput: "", standardError: errorOutput)
        }

        let service = GhosttyCLIService(
            locator: GhosttyExecutableLocator(customPath: dummyExecutable, isExecutableFile: { _ in true }),
            processRunner: runner,
            fileExists: { _ in true }
        )

        let configURL = URL(fileURLWithPath: "/tmp/theme_test.ghostty")
        let result = try service.validateConfig(at: configURL)

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.issues.count, 1)
        XCTAssertNil(result.issues[0].line)
        XCTAssertNil(result.issues[0].key)
        XCTAssertTrue(result.issues[0].message.contains("theme \"NonExistent\" not found"))
    }

    // 5. Target file does not exist on disk
    func testValidateConfigFileDoesNotExist() throws {
        let runner = MockProcessRunner()
        let service = GhosttyCLIService(
            locator: GhosttyExecutableLocator(customPath: dummyExecutable, isExecutableFile: { _ in true }),
            processRunner: runner,
            fileExists: { _ in false }
        )

        let configURL = URL(fileURLWithPath: "/tmp/does_not_exist.ghostty")
        let result = try service.validateConfig(at: configURL)

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.issues.count, 1)
        XCTAssertEqual(result.issues[0].message, "Configuration file does not exist at specified path.")
        XCTAssertEqual(runner.invocations.count, 0) // Did not invoke process unnecessarily
    }

    // 6. List fonts parsing
    func testListFonts() throws {
        let fontOutput = """
        Andale Mono
          Andale Mono

        Courier New
          Courier New
          Courier New Bold
          Courier New Bold Italic

        Monaco
        """

        let runner = MockProcessRunner { _ in
            ProcessOutput(exitCode: 0, standardOutput: fontOutput, standardError: "")
        }

        let service = GhosttyCLIService(
            locator: GhosttyExecutableLocator(customPath: dummyExecutable, isExecutableFile: { _ in true }),
            processRunner: runner
        )

        let fonts = try service.listFonts()
        XCTAssertEqual(fonts.count, 3)

        XCTAssertEqual(fonts[0].name, "Andale Mono")
        XCTAssertEqual(fonts[0].styles, ["Andale Mono"])

        XCTAssertEqual(fonts[1].name, "Courier New")
        XCTAssertEqual(fonts[1].styles, ["Courier New", "Courier New Bold", "Courier New Bold Italic"])

        XCTAssertEqual(fonts[2].name, "Monaco")
        XCTAssertEqual(fonts[2].styles, [])
    }

    // 7. List fonts execution failure throws error
    func testListFontsFailureThrows() {
        let runner = MockProcessRunner { _ in
            ProcessOutput(exitCode: 1, standardOutput: "", standardError: "Failed to list fonts")
        }

        let service = GhosttyCLIService(
            locator: GhosttyExecutableLocator(customPath: dummyExecutable, isExecutableFile: { _ in true }),
            processRunner: runner
        )

        XCTAssertThrowsError(try service.listFonts()) { error in
            guard let cliError = error as? GhosttyCLIError else {
                XCTFail("Expected GhosttyCLIError, got \(error)")
                return
            }
            if case .executionFailed(let cmd, let code, _) = cliError {
                XCTAssertTrue(cmd.contains("+list-fonts"))
                XCTAssertEqual(code, 1)
            } else {
                XCTFail("Expected executionFailed, got \(cliError)")
            }
        }
    }

    // 8. List themes parsing with origins and parentheses
    func testListThemesParsing() throws {
        let themeOutput = """
        0x96f (resources)
        Black Metal (Bathory) (resources)
        Custom User Theme (config)
        Plain Theme
        """

        let runner = MockProcessRunner { _ in
            ProcessOutput(exitCode: 0, standardOutput: themeOutput, standardError: "")
        }

        let service = GhosttyCLIService(
            locator: GhosttyExecutableLocator(customPath: dummyExecutable, isExecutableFile: { _ in true }),
            processRunner: runner
        )

        let themes = try service.listThemes(colorScheme: .all)
        XCTAssertEqual(themes.count, 4)

        XCTAssertEqual(themes[0].name, "0x96f")
        XCTAssertEqual(themes[0].origin, "resources")

        XCTAssertEqual(themes[1].name, "Black Metal (Bathory)")
        XCTAssertEqual(themes[1].origin, "resources")

        XCTAssertEqual(themes[2].name, "Custom User Theme")
        XCTAssertEqual(themes[2].origin, "config")

        XCTAssertEqual(themes[3].name, "Plain Theme")
        XCTAssertNil(themes[3].origin)
    }

    // 9. List themes with color scheme filtering
    func testListThemesColorSchemeArgument() throws {
        let runner = MockProcessRunner { _ in
            ProcessOutput(exitCode: 0, standardOutput: "Dark Theme (resources)\n", standardError: "")
        }

        let service = GhosttyCLIService(
            locator: GhosttyExecutableLocator(customPath: dummyExecutable, isExecutableFile: { _ in true }),
            processRunner: runner
        )

        _ = try service.listThemes(colorScheme: .dark)
        XCTAssertEqual(runner.invocations.last?.arguments, ["+list-themes", "--plain", "--color=dark"])

        _ = try service.listThemes(colorScheme: .light)
        XCTAssertEqual(runner.invocations.last?.arguments, ["+list-themes", "--plain", "--color=light"])

        _ = try service.listThemes(colorScheme: .all)
        XCTAssertEqual(runner.invocations.last?.arguments, ["+list-themes", "--plain"])
    }

    // 10. Default configuration retrieval
    func testGetDefaultConfigDocument() throws {
        let sampleConfig = """
        # Ghostty defaults
        font-family = Monaco
        font-size = 13
        theme = 3024 Night
        """

        let runner = MockProcessRunner { invocation in
            XCTAssertEqual(invocation.arguments, ["+show-config", "--default"])
            return ProcessOutput(exitCode: 0, standardOutput: sampleConfig, standardError: "")
        }

        let service = GhosttyCLIService(
            locator: GhosttyExecutableLocator(customPath: dummyExecutable, isExecutableFile: { _ in true }),
            processRunner: runner
        )

        let doc = try service.getDefaultConfigDocument()
        XCTAssertEqual(doc.effectiveValue(for: "font-family"), "Monaco")
        XCTAssertEqual(doc.effectiveValue(for: "font-size"), "13")
        XCTAssertEqual(doc.effectiveValue(for: "theme"), "3024 Night")
    }

    // 11. Version retrieval
    func testGetVersion() throws {
        let runner = MockProcessRunner { invocation in
            XCTAssertEqual(invocation.arguments, ["+version"])
            return ProcessOutput(exitCode: 0, standardOutput: "Ghostty 1.3.1\n\nVersion\n  - version: 1.3.1", standardError: "")
        }

        let service = GhosttyCLIService(
            locator: GhosttyExecutableLocator(customPath: dummyExecutable, isExecutableFile: { _ in true }),
            processRunner: runner
        )

        let version = try service.getVersion()
        XCTAssertTrue(version.hasPrefix("Ghostty 1.3.1"))
    }

    // 12. Live integration test with real Ghostty installation (if installed)
    func testLiveGhosttyCLIIntegrationIfInstalled() throws {
        let locator = GhosttyExecutableLocator()
        guard locator.isGhosttyInstalled(), let execURL = locator.findExecutable() else {
            // Skip if Ghostty is not installed on this machine
            return
        }

        let service = GhosttyCLIService(locator: locator, processRunner: SystemProcessRunner())

        // 1. Verify executable URL
        XCTAssertEqual(try service.executableURL(), execURL)

        // 2. Verify version
        let version = try service.getVersion()
        XCTAssertFalse(version.isEmpty)
        XCTAssertTrue(version.contains("Ghostty"))

        // 3. Verify fonts
        let fonts = try service.listFonts()
        XCTAssertFalse(fonts.isEmpty)

        // 4. Verify themes
        let themes = try service.listThemes(colorScheme: .all)
        XCTAssertFalse(themes.isEmpty)

        // 5. Verify validation on a temporary valid config file
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let validConfigURL = tempDir.appendingPathComponent("config.ghostty")
        try "font-size = 14\n".write(to: validConfigURL, atomically: true, encoding: .utf8)

        let validResult = try service.validateConfig(at: validConfigURL)
        XCTAssertTrue(validResult.isValid)
        XCTAssertTrue(validResult.issues.isEmpty)

        // 6. Verify validation on a temporary invalid config file
        let invalidConfigURL = tempDir.appendingPathComponent("invalid.ghostty")
        try "non_existent_ghostty_key_xyz = 123\n".write(to: invalidConfigURL, atomically: true, encoding: .utf8)

        let invalidResult = try service.validateConfig(at: invalidConfigURL)
        XCTAssertFalse(invalidResult.isValid)
        XCTAssertFalse(invalidResult.issues.isEmpty)
    }
}
