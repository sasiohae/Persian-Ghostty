import Foundation

/// Supported shell environments for interactive Persian integration.
public enum PersianShellType: String, CaseIterable, Identifiable, Sendable {
    case zsh = "zsh"
    case fish = "fish"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .zsh: return "Zsh"
        case .fish: return "Fish"
        }
    }

    public var binaryName: String {
        rawValue
    }

    /// Default configuration file name or relative path in user home directory.
    public var relativeConfigPath: String {
        switch self {
        case .zsh:
            return ".zshrc"
        case .fish:
            return ".config/fish/conf.d/ghostty_persian.fish"
        }
    }
}

/// Comprehensive status of Persian interactive shell integration.
public struct PersianShellStatus: Sendable, Equatable {
    public let shell: PersianShellType
    public let isInstalled: Bool
    public let configURL: URL
    public let isBiDiHelperAvailable: Bool
    public let biDiHelperPath: String?
    public let lastCheckedDate: Date

    public init(
        shell: PersianShellType,
        isInstalled: Bool,
        configURL: URL,
        isBiDiHelperAvailable: Bool,
        biDiHelperPath: String? = nil,
        lastCheckedDate: Date = Date()
    ) {
        self.shell = shell
        self.isInstalled = isInstalled
        self.configURL = configURL
        self.isBiDiHelperAvailable = isBiDiHelperAvailable
        self.biDiHelperPath = biDiHelperPath
        self.lastCheckedDate = lastCheckedDate
    }
}

/// Start and end markers for safe non-destructive script injection.
public enum PersianShellMarkers {
    public static let startMarker = "# >>> GhosttyPersian Shell Integration >>>"
    public static let endMarker = "# <<< GhosttyPersian Shell Integration <<<"
}

/// Errors occurring during shell integration operations.
public enum PersianShellIntegrationError: LocalizedError, Equatable {
    case fileReadFailed(url: URL, underlyingError: String)
    case fileWriteFailed(url: URL, underlyingError: String)
    case directoryCreationFailed(url: URL, underlyingError: String)
    case removalFailed(url: URL, underlyingError: String)

    public var errorDescription: String? {
        switch self {
        case .fileReadFailed(let url, let error):
            return "Failed to read shell configuration file at '\(url.path)': \(error)"
        case .fileWriteFailed(let url, let error):
            return "Failed to write shell integration file at '\(url.path)': \(error)"
        case .directoryCreationFailed(let url, let error):
            return "Failed to create directory at '\(url.path)': \(error)"
        case .removalFailed(let url, let error):
            return "Failed to remove shell integration from '\(url.path)': \(error)"
        }
    }
}
