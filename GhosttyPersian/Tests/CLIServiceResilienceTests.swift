import XCTest
@testable import GhosttyPersian

final class CLIServiceResilienceTests: XCTestCase {
    private let dummyExec = URL(fileURLWithPath: "/usr/local/bin/ghostty")

    // MARK: - 1. Process Timeout Handling

    func testCLIServiceProcessTimeout() {
        let runner = MockTimeoutProcessRunner()
        let locator = GhosttyExecutableLocator(customPath: dummyExec, isExecutableFile: { _ in true })
        let service = GhosttyCLIService(locator: locator, processRunner: runner, defaultTimeout: 0.1)

        XCTAssertThrowsError(try service.listFonts()) { error in
            guard let cliError = error as? GhosttyCLIError else {
                XCTFail("Expected GhosttyCLIError, got \(error)")
                return
            }
            if case .processTimeout(let cmd, let timeout) = cliError {
                XCTAssertEqual(cmd, "ghostty +list-fonts")
                XCTAssertEqual(timeout, 0.1)
            } else {
                XCTFail("Expected processTimeout, got \(cliError)")
            }
        }
    }

    // MARK: - 2. Malformed CLI Stderr and Stdout

    func testValidationWithMalformedDiagnosticLines() throws {
        // Output that does NOT match the standard "file:line:key: message" format
        let malformedError = """
        fatal: unable to read config
        unexpected token on line ???
        === STACK TRACE ===
        ghostty: [error] segmentation or corruption
        """
        let runner = MockOutputProcessRunner(output: ProcessOutput(exitCode: 1, standardOutput: "", standardError: malformedError))
        let locator = GhosttyExecutableLocator(customPath: dummyExec, isExecutableFile: { _ in true })
        let service = GhosttyCLIService(locator: locator, processRunner: runner, fileExists: { _ in true })

        let result = try service.validateConfig(at: URL(fileURLWithPath: "/tmp/test.ghostty"))
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.issues.count, 4) // Each non-empty line captured as diagnostic issue
        XCTAssertEqual(result.rawOutput, malformedError)
    }

    func testListFontsWithCorruptedOutput() throws {
        let corruptedOutput = """
        Invalid Font Header


        Regular (style without family)
        JetBrains Mono
          Regular
          Bold
        """
        let runner = MockOutputProcessRunner(output: ProcessOutput(exitCode: 0, standardOutput: corruptedOutput, standardError: ""))
        let locator = GhosttyExecutableLocator(customPath: dummyExec, isExecutableFile: { _ in true })
        let service = GhosttyCLIService(locator: locator, processRunner: runner)

        let fonts = try service.listFonts()
        // Should parse JetBrains Mono safely without crashing
        XCTAssertTrue(fonts.contains { $0.name == "JetBrains Mono" })
    }

    func testListThemesWithMalformedLines() throws {
        let malformedThemes = """


        ValidThemeOne
        ValidThemeTwo
        """
        let runner = MockOutputProcessRunner(output: ProcessOutput(exitCode: 0, standardOutput: malformedThemes, standardError: ""))
        let locator = GhosttyExecutableLocator(customPath: dummyExec, isExecutableFile: { _ in true })
        let service = GhosttyCLIService(locator: locator, processRunner: runner)

        let themes = try service.listThemes(colorScheme: .all)
        XCTAssertEqual(themes.count, 2)
        XCTAssertEqual(themes[0].name, "ValidThemeOne")
        XCTAssertEqual(themes[1].name, "ValidThemeTwo")
    }

    // MARK: - 3. Missing Executable Fallback

    func testMissingExecutableFallbackBehavior() {
        let missingLocator = GhosttyExecutableLocator(customPath: nil, environment: [:], isExecutableFile: { _ in false })
        let service = GhosttyCLIService(locator: missingLocator)

        XCTAssertFalse(service.isGhosttyInstalled())
        XCTAssertThrowsError(try service.getVersion()) { error in
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

    // MARK: - 4. Execution Failure With Non-Zero Exit Code

    func testCommandExecutionFailureWithNonZeroExitCode() {
        let runner = MockOutputProcessRunner(output: ProcessOutput(exitCode: 127, standardOutput: "", standardError: "command not found: ghostty"))
        let locator = GhosttyExecutableLocator(customPath: dummyExec, isExecutableFile: { _ in true })
        let service = GhosttyCLIService(locator: locator, processRunner: runner)

        XCTAssertThrowsError(try service.getVersion()) { error in
            guard let cliError = error as? GhosttyCLIError else {
                XCTFail("Expected GhosttyCLIError, got \(error)")
                return
            }
            if case .executionFailed(let cmd, let code, let stderr) = cliError {
                XCTAssertEqual(cmd, "ghostty +version")
                XCTAssertEqual(code, 127)
                XCTAssertEqual(stderr, "command not found: ghostty")
            } else {
                XCTFail("Expected executionFailed, got \(cliError)")
            }
        }
    }
}

// MARK: - Mocks

private struct MockTimeoutProcessRunner: ProcessRunning {
    func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]?,
        currentDirectoryURL: URL?,
        timeout: TimeInterval?
    ) throws -> ProcessOutput {
        throw GhosttyCLIError.processTimeout(command: "ghostty \(arguments.joined(separator: " "))", timeout: timeout ?? 15.0)
    }
}

private struct MockOutputProcessRunner: ProcessRunning {
    let output: ProcessOutput

    func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]?,
        currentDirectoryURL: URL?,
        timeout: TimeInterval?
    ) throws -> ProcessOutput {
        output
    }
}
