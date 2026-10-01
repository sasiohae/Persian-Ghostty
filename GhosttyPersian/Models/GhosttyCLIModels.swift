import Foundation

/// Represents a font family discovered from Ghostty CLI.
public struct GhosttyFontFamily: Sendable, Equatable, Identifiable, Hashable {
    public var id: String { name }

    /// The name of the font family (e.g., "Menlo", "JetBrainsMono Nerd Font Mono").
    public let name: String

    /// The font styles/variants available within this family (e.g., "Regular", "Bold", "Italic").
    public let styles: [String]

    public init(name: String, styles: [String] = []) {
        self.name = name
        self.styles = styles
    }
}

/// Filter for theme listing based on color scheme.
public enum GhosttyThemeColorScheme: String, Sendable, CaseIterable, Equatable {
    case all = "all"
    case dark = "dark"
    case light = "light"
}

/// Represents a theme discovered from Ghostty CLI.
public struct GhosttyTheme: Sendable, Equatable, Identifiable, Hashable {
    public var id: String { name }

    /// The theme name to use in configuration (e.g., "3024 Night", "Aizen Dark").
    public let name: String

    /// The source/origin of the theme if specified (e.g., "resources", "config").
    public let origin: String?

    public init(name: String, origin: String? = nil) {
        self.name = name
        self.origin = origin
    }
}

/// Represents an individual issue discovered during configuration validation.
public struct GhosttyValidationIssue: Sendable, Equatable, Identifiable {
    public var id: String { "\(filePath ?? ""):\(line ?? 0):\(key ?? ""):\(message)" }

    /// The configuration file path where the issue occurred, if available.
    public let filePath: String?

    /// The line number where the issue occurred, if available.
    public let line: Int?

    /// The configuration key associated with the issue, if available.
    public let key: String?

    /// The human-readable error or warning message.
    public let message: String

    /// The original raw error line from the Ghostty output.
    public let rawText: String

    public init(
        filePath: String? = nil,
        line: Int? = nil,
        key: String? = nil,
        message: String,
        rawText: String? = nil
    ) {
        self.filePath = filePath
        self.line = line
        self.key = key
        self.message = message
        self.rawText = rawText ?? message
    }
}

/// Represents the overall result of validating a configuration file with Ghostty.
public struct GhosttyValidationResult: Sendable, Equatable {
    /// Whether the configuration is valid according to Ghostty.
    public let isValid: Bool

    /// List of validation issues/diagnostics if invalid.
    public let issues: [GhosttyValidationIssue]

    /// The full raw output produced by Ghostty during validation.
    public let rawOutput: String

    public init(isValid: Bool, issues: [GhosttyValidationIssue] = [], rawOutput: String = "") {
        self.isValid = isValid
        self.issues = issues
        self.rawOutput = rawOutput
    }

    /// Convenience instance representing valid configuration.
    public static var valid: GhosttyValidationResult {
        GhosttyValidationResult(isValid: true, issues: [], rawOutput: "")
    }
}

/// Errors occurring during Ghostty CLI operations.
public enum GhosttyCLIError: LocalizedError, Sendable, Equatable {
    /// Ghostty executable could not be found at any candidate location.
    case executableNotFound(searchedPaths: [String])

    /// The execution of a CLI command returned a non-zero exit code.
    case executionFailed(command: String, exitCode: Int32, standardError: String)

    /// Process execution exceeded the specified timeout.
    case processTimeout(command: String, timeout: TimeInterval)

    /// Output from Ghostty CLI was unexpected or malformed.
    case invalidOutput(command: String, details: String)

    public var errorDescription: String? {
        switch self {
        case .executableNotFound(let paths):
            return "Ghostty executable was not found. Searched paths: \(paths.joined(separator: ", "))"
        case .executionFailed(let command, let exitCode, let stderr):
            let trimmedError = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let details = trimmedError.isEmpty ? "Exit code \(exitCode)" : trimmedError
            return "Ghostty command '\(command)' failed: \(details)"
        case .processTimeout(let command, let timeout):
            return "Ghostty command '\(command)' timed out after \(timeout) seconds."
        case .invalidOutput(let command, let details):
            return "Invalid output from Ghostty command '\(command)': \(details)"
        }
    }
}
