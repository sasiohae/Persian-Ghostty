import Foundation

/// Captures the execution outcome of an external system process.
public struct ProcessOutput: Sendable, Equatable {
    /// The termination status of the process.
    public let exitCode: Int32

    /// Captured standard output as a UTF-8 string.
    public let standardOutput: String

    /// Captured standard error as a UTF-8 string.
    public let standardError: String

    /// Convenience check for exit code 0.
    public var isSuccess: Bool {
        exitCode == 0
    }

    public init(exitCode: Int32, standardOutput: String, standardError: String) {
        self.exitCode = exitCode
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

/// Abstract contract for running system processes in a testable manner.
public protocol ProcessRunning: Sendable {
    /// Executes a process with the specified configuration.
    func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]?,
        currentDirectoryURL: URL?,
        timeout: TimeInterval?
    ) throws -> ProcessOutput
}

public extension ProcessRunning {
    /// Convenience runner with default environment, directory, and timeout.
    func run(
        executableURL: URL,
        arguments: [String],
        timeout: TimeInterval? = 15.0
    ) throws -> ProcessOutput {
        try run(
            executableURL: executableURL,
            arguments: arguments,
            environment: nil,
            currentDirectoryURL: nil,
            timeout: timeout
        )
    }
}

/// Concrete implementation of `ProcessRunning` utilizing `Foundation.Process`.
public struct SystemProcessRunner: ProcessRunning {
    public init() {}

    public func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]?,
        currentDirectoryURL: URL?,
        timeout: TimeInterval?
    ) throws -> ProcessOutput {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        if let environment = environment {
            process.environment = environment
        }

        if let currentDirectoryURL = currentDirectoryURL {
            process.currentDirectoryURL = currentDirectoryURL
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        var stdoutData = Data()
        var stderrData = Data()
        let readGroup = DispatchGroup()

        readGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            readGroup.leave()
        }

        readGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            readGroup.leave()
        }

        do {
            try process.run()
        } catch {
            // Clean up read group handles if launching the process failed
            try? stdoutPipe.fileHandleForWriting.close()
            try? stderrPipe.fileHandleForWriting.close()
            readGroup.wait()
            throw error
        }

        let commandString = ([executableURL.path] + arguments).joined(separator: " ")

        if let timeout = timeout, timeout > 0 {
            let waitResult = readGroup.wait(timeout: .now() + timeout)
            if waitResult == .timedOut {
                process.terminate()
                process.waitUntilExit()
                throw GhosttyCLIError.processTimeout(command: commandString, timeout: timeout)
            }
        } else {
            readGroup.wait()
        }

        process.waitUntilExit()

        let stdoutString = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderrString = String(data: stderrData, encoding: .utf8) ?? ""

        return ProcessOutput(
            exitCode: process.terminationStatus,
            standardOutput: stdoutString,
            standardError: stderrString
        )
    }
}

/// Mock process runner for unit tests.
public final class MockProcessRunner: ProcessRunning, @unchecked Sendable {
    public struct Invocation: Sendable, Equatable {
        public let executableURL: URL
        public let arguments: [String]
        public let environment: [String: String]?
        public let currentDirectoryURL: URL?
        public let timeout: TimeInterval?

        public init(
            executableURL: URL,
            arguments: [String],
            environment: [String: String]? = nil,
            currentDirectoryURL: URL? = nil,
            timeout: TimeInterval? = nil
        ) {
            self.executableURL = executableURL
            self.arguments = arguments
            self.environment = environment
            self.currentDirectoryURL = currentDirectoryURL
            self.timeout = timeout
        }
    }

    private let lock = NSLock()
    private var _invocations: [Invocation] = []
    public var handler: (@Sendable (Invocation) throws -> ProcessOutput)?

    public init(handler: (@Sendable (Invocation) throws -> ProcessOutput)? = nil) {
        self.handler = handler
    }

    public var invocations: [Invocation] {
        lock.lock()
        defer { lock.unlock() }
        return _invocations
    }

    public func clearInvocations() {
        lock.lock()
        defer { lock.unlock() }
        _invocations.removeAll()
    }

    public func run(
        executableURL: URL,
        arguments: [String],
        environment: [String: String]?,
        currentDirectoryURL: URL?,
        timeout: TimeInterval?
    ) throws -> ProcessOutput {
        let invocation = Invocation(
            executableURL: executableURL,
            arguments: arguments,
            environment: environment,
            currentDirectoryURL: currentDirectoryURL,
            timeout: timeout
        )
        lock.lock()
        _invocations.append(invocation)
        lock.unlock()

        if let handler = handler {
            return try handler(invocation)
        }

        return ProcessOutput(exitCode: 0, standardOutput: "", standardError: "")
    }
}
