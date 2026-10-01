import Foundation

/// Protocol defining the Ghostty CLI service capabilities.
public protocol GhosttyCLIServiceProtocol: Sendable {
    /// Checks whether Ghostty executable is available on the machine.
    func isGhosttyInstalled() -> Bool

    /// Resolves the URL of the Ghostty executable or throws an error if not found.
    func executableURL() throws -> URL

    /// Validates a Ghostty configuration file using `ghostty +validate-config --config-file=<path>`.
    func validateConfig(at fileURL: URL) throws -> GhosttyValidationResult

    /// Retrieves all available fonts using `ghostty +list-fonts`.
    func listFonts() throws -> [GhosttyFontFamily]

    /// Retrieves all available themes using `ghostty +list-themes --plain`.
    func listThemes(colorScheme: GhosttyThemeColorScheme) throws -> [GhosttyTheme]

    /// Retrieves the default Ghostty configuration as a `GhosttyConfigDocument`.
    func getDefaultConfigDocument() throws -> GhosttyConfigDocument

    /// Retrieves the Ghostty version information using `ghostty +version`.
    func getVersion() throws -> String
}

/// Service that interacts directly with the Ghostty CLI to perform read-only operations.
public final class GhosttyCLIService: GhosttyCLIServiceProtocol, @unchecked Sendable {
    public let locator: GhosttyExecutableLocator
    public let processRunner: ProcessRunning
    public let defaultTimeout: TimeInterval

    private let fileExists: @Sendable (String) -> Bool

    public init(
        locator: GhosttyExecutableLocator = GhosttyExecutableLocator(),
        processRunner: ProcessRunning = SystemProcessRunner(),
        defaultTimeout: TimeInterval = 15.0,
        fileExists: @escaping @Sendable (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) {
        self.locator = locator
        self.processRunner = processRunner
        self.defaultTimeout = defaultTimeout
        self.fileExists = fileExists
    }

    // MARK: - Executable Discovery

    public func isGhosttyInstalled() -> Bool {
        locator.isGhosttyInstalled()
    }

    public func executableURL() throws -> URL {
        guard let url = locator.findExecutable() else {
            throw GhosttyCLIError.executableNotFound(searchedPaths: locator.candidatePaths())
        }
        return url
    }

    // MARK: - Validation

    public func validateConfig(at fileURL: URL) throws -> GhosttyValidationResult {
        guard fileExists(fileURL.path) else {
            let notFoundIssue = GhosttyValidationIssue(
                filePath: fileURL.path,
                line: nil,
                key: nil,
                message: "Configuration file does not exist at specified path.",
                rawText: "File does not exist: \(fileURL.path)"
            )
            return GhosttyValidationResult(
                isValid: false,
                issues: [notFoundIssue],
                rawOutput: "File does not exist: \(fileURL.path)"
            )
        }

        let execURL = try executableURL()
        let arguments = ["+validate-config", "--config-file=\(fileURL.path)"]

        let output = try processRunner.run(
            executableURL: execURL,
            arguments: arguments,
            environment: nil,
            currentDirectoryURL: nil,
            timeout: defaultTimeout
        )

        return Self.parseValidationOutput(output: output, targetFileURL: fileURL)
    }

    // MARK: - Fonts

    public func listFonts() throws -> [GhosttyFontFamily] {
        let execURL = try executableURL()
        let arguments = ["+list-fonts"]

        let output = try processRunner.run(
            executableURL: execURL,
            arguments: arguments,
            environment: nil,
            currentDirectoryURL: nil,
            timeout: defaultTimeout
        )

        guard output.isSuccess else {
            throw GhosttyCLIError.executionFailed(
                command: "ghostty +list-fonts",
                exitCode: output.exitCode,
                standardError: output.standardError
            )
        }

        return Self.parseFontList(output.standardOutput)
    }

    // MARK: - Themes

    public func listThemes(colorScheme: GhosttyThemeColorScheme = .all) throws -> [GhosttyTheme] {
        let execURL = try executableURL()
        var arguments = ["+list-themes", "--plain"]
        if colorScheme != .all {
            arguments.append("--color=\(colorScheme.rawValue)")
        }

        let output = try processRunner.run(
            executableURL: execURL,
            arguments: arguments,
            environment: nil,
            currentDirectoryURL: nil,
            timeout: defaultTimeout
        )

        guard output.isSuccess else {
            throw GhosttyCLIError.executionFailed(
                command: "ghostty \(arguments.joined(separator: " "))",
                exitCode: output.exitCode,
                standardError: output.standardError
            )
        }

        return Self.parseThemeList(output.standardOutput)
    }

    // MARK: - Default Configuration

    public func getDefaultConfigDocument() throws -> GhosttyConfigDocument {
        let execURL = try executableURL()
        let arguments = ["+show-config", "--default"]

        let output = try processRunner.run(
            executableURL: execURL,
            arguments: arguments,
            environment: nil,
            currentDirectoryURL: nil,
            timeout: defaultTimeout
        )

        guard output.isSuccess else {
            throw GhosttyCLIError.executionFailed(
                command: "ghostty +show-config --default",
                exitCode: output.exitCode,
                standardError: output.standardError
            )
        }

        let parser = GhosttyConfigParser()
        return parser.parse(output.standardOutput)
    }

    // MARK: - Version

    public func getVersion() throws -> String {
        let execURL = try executableURL()
        let arguments = ["+version"]

        let output = try processRunner.run(
            executableURL: execURL,
            arguments: arguments,
            environment: nil,
            currentDirectoryURL: nil,
            timeout: defaultTimeout
        )

        guard output.isSuccess else {
            throw GhosttyCLIError.executionFailed(
                command: "ghostty +version",
                exitCode: output.exitCode,
                standardError: output.standardError
            )
        }

        return output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Parsers

    /// Parses the stdout/stderr output from `ghostty +validate-config`.
    public static func parseValidationOutput(output: ProcessOutput, targetFileURL: URL) -> GhosttyValidationResult {
        let combinedOutput = [output.standardError, output.standardOutput]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if output.isSuccess && combinedOutput.isEmpty {
            return .valid
        }

        var issues: [GhosttyValidationIssue] = []
        let lines = combinedOutput.components(separatedBy: .newlines)

        // Pattern matching: /path/to/file:line:optionalKey: message
        let linePattern = #"^(.+?):(\d+):(?:([^:]+):)?\s*(.+)$"#
        let regex = try? NSRegularExpression(pattern: linePattern)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if let regex = regex,
               let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
                let filePath = (trimmed as NSString).substring(with: match.range(at: 1))
                let lineNum = Int((trimmed as NSString).substring(with: match.range(at: 2)))
                let key: String? = match.range(at: 3).location != NSNotFound
                    ? (trimmed as NSString).substring(with: match.range(at: 3)).trimmingCharacters(in: .whitespaces)
                    : nil
                let message = (trimmed as NSString).substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)

                issues.append(GhosttyValidationIssue(
                    filePath: filePath,
                    line: lineNum,
                    key: key,
                    message: message,
                    rawText: trimmed
                ))
            } else {
                // Generic error or warning line (e.g. theme not found diagnostics)
                issues.append(GhosttyValidationIssue(
                    filePath: targetFileURL.path,
                    line: nil,
                    key: nil,
                    message: trimmed,
                    rawText: trimmed
                ))
            }
        }

        if issues.isEmpty && !output.isSuccess {
            issues.append(GhosttyValidationIssue(
                filePath: targetFileURL.path,
                line: nil,
                key: nil,
                message: "Ghostty validation failed with exit code \(output.exitCode).",
                rawText: combinedOutput
            ))
        }

        let isValid = output.isSuccess && issues.isEmpty
        return GhosttyValidationResult(
            isValid: isValid,
            issues: issues,
            rawOutput: combinedOutput
        )
    }

    /// Parses the output from `ghostty +list-fonts`.
    public static func parseFontList(_ output: String) -> [GhosttyFontFamily] {
        var families: [GhosttyFontFamily] = []
        var currentFamilyName: String?
        var currentStyles: [String] = []

        func flushCurrentFamily() {
            if let name = currentFamilyName {
                families.append(GhosttyFontFamily(name: name, styles: currentStyles))
                currentFamilyName = nil
                currentStyles = []
            }
        }

        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                flushCurrentFamily()
                continue
            }

            if line.hasPrefix("  ") || line.hasPrefix("\t") {
                currentStyles.append(trimmed)
            } else {
                flushCurrentFamily()
                currentFamilyName = trimmed
            }
        }

        flushCurrentFamily()
        return families
    }

    /// Parses the output from `ghostty +list-themes --plain`.
    public static func parseThemeList(_ output: String) -> [GhosttyTheme] {
        var themes: [GhosttyTheme] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if trimmed.hasSuffix(")"), let openParen = trimmed.lastIndex(of: "(") {
                let name = String(trimmed[..<openParen]).trimmingCharacters(in: .whitespaces)
                let origin = String(trimmed[trimmed.index(after: openParen)..<trimmed.index(before: trimmed.endIndex)])
                    .trimmingCharacters(in: .whitespaces)

                if !name.isEmpty {
                    themes.append(GhosttyTheme(name: name, origin: origin.isEmpty ? nil : origin))
                } else {
                    themes.append(GhosttyTheme(name: trimmed, origin: nil))
                }
            } else {
                themes.append(GhosttyTheme(name: trimmed, origin: nil))
            }
        }

        return themes
    }
}
