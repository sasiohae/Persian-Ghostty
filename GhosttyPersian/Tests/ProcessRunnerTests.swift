import XCTest
@testable import GhosttyPersian

final class ProcessRunnerTests: XCTestCase {
    // 1. ProcessOutput success check
    func testProcessOutputSuccess() {
        let successOutput = ProcessOutput(exitCode: 0, standardOutput: "ok", standardError: "")
        XCTAssertTrue(successOutput.isSuccess)

        let failureOutput = ProcessOutput(exitCode: 1, standardOutput: "", standardError: "error")
        XCTAssertFalse(failureOutput.isSuccess)
    }

    // 2. SystemProcessRunner runs echo command successfully
    func testSystemProcessRunnerEcho() throws {
        let runner = SystemProcessRunner()
        let echoURL = URL(fileURLWithPath: "/bin/echo")

        let output = try runner.run(
            executableURL: echoURL,
            arguments: ["hello", "ghostty"],
            timeout: 5.0
        )

        XCTAssertTrue(output.isSuccess)
        XCTAssertEqual(output.exitCode, 0)
        XCTAssertEqual(output.standardOutput.trimmingCharacters(in: .newlines), "hello ghostty")
        XCTAssertEqual(output.standardError, "")
    }

    // 3. SystemProcessRunner handles non-zero exit codes
    func testSystemProcessRunnerFailureExitCode() throws {
        let runner = SystemProcessRunner()
        let testURL = URL(fileURLWithPath: "/usr/bin/false")

        let output = try runner.run(
            executableURL: testURL,
            arguments: [],
            timeout: 5.0
        )

        XCTAssertFalse(output.isSuccess)
        XCTAssertNotEqual(output.exitCode, 0)
    }

    // 4. SystemProcessRunner enforces timeout
    func testSystemProcessRunnerTimeout() {
        let runner = SystemProcessRunner()
        let sleepURL = URL(fileURLWithPath: "/bin/sleep")

        XCTAssertThrowsError(
            try runner.run(
                executableURL: sleepURL,
                arguments: ["10"],
                timeout: 0.2
            )
        ) { error in
            guard let cliError = error as? GhosttyCLIError else {
                XCTFail("Expected GhosttyCLIError, got \(error)")
                return
            }
            if case .processTimeout(let command, let timeout) = cliError {
                XCTAssertTrue(command.contains("sleep"))
                XCTAssertEqual(timeout, 0.2)
            } else {
                XCTFail("Expected processTimeout case, got \(cliError)")
            }
        }
    }

    // 5. MockProcessRunner records invocations accurately
    func testMockProcessRunnerRecording() throws {
        let mock = MockProcessRunner()
        let testURL = URL(fileURLWithPath: "/dummy/ghostty")

        _ = try mock.run(
            executableURL: testURL,
            arguments: ["+version"],
            timeout: 10.0
        )

        XCTAssertEqual(mock.invocations.count, 1)
        XCTAssertEqual(mock.invocations[0].executableURL, testURL)
        XCTAssertEqual(mock.invocations[0].arguments, ["+version"])
        XCTAssertEqual(mock.invocations[0].timeout, 10.0)

        mock.clearInvocations()
        XCTAssertEqual(mock.invocations.count, 0)
    }

    // 6. MockProcessRunner uses custom handler
    func testMockProcessRunnerHandler() throws {
        let mock = MockProcessRunner { invocation in
            if invocation.arguments == ["+list-fonts"] {
                return ProcessOutput(exitCode: 0, standardOutput: "Menlo\n  Menlo Regular", standardError: "")
            }
            return ProcessOutput(exitCode: 1, standardOutput: "", standardError: "Unknown action")
        }

        let testURL = URL(fileURLWithPath: "/dummy/ghostty")
        let fontOutput = try mock.run(executableURL: testURL, arguments: ["+list-fonts"])
        XCTAssertTrue(fontOutput.isSuccess)
        XCTAssertEqual(fontOutput.standardOutput, "Menlo\n  Menlo Regular")

        let unknownOutput = try mock.run(executableURL: testURL, arguments: ["+unknown"])
        XCTAssertFalse(unknownOutput.isSuccess)
        XCTAssertEqual(unknownOutput.standardError, "Unknown action")
    }
}
