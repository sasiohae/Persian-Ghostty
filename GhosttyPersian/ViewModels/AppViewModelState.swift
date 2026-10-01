import Foundation

/// Status of the external Ghostty CLI binary.
public struct GhosttyCLIStatus: Sendable, Equatable {
    public let isAvailable: Bool
    public let executableURL: URL?
    public let version: String?
    public let errorMessage: String?

    public init(
        isAvailable: Bool = false,
        executableURL: URL? = nil,
        version: String? = nil,
        errorMessage: String? = nil
    ) {
        self.isAvailable = isAvailable
        self.executableURL = executableURL
        self.version = version
        self.errorMessage = errorMessage
    }

    public static var unavailable: GhosttyCLIStatus {
        GhosttyCLIStatus(
            isAvailable: false,
            executableURL: nil,
            version: nil,
            errorMessage: "Ghostty executable not found"
        )
    }
}

/// Loading state for the configuration file.
public enum ConfigurationLoadingState: Sendable, Equatable {
    case idle
    case loading
    case loaded(LoadedConfiguration)
    case notFound(recommendedPath: URL)
    case failed(String)
}

/// State of configuration validation.
public enum ValidationState: Sendable, Equatable {
    case unknown
    case validating
    case valid
    case invalid([GhosttyValidationIssue], rawOutput: String)
    case skipped(reason: String)
}

/// State of configuration saving.
public enum SaveState: Sendable, Equatable {
    case idle
    case saving
    case saved(SaveResult)
    case failed(String)
}

/// Asynchronous state of discovered fonts.
public struct FontsState: Sendable, Equatable {
    public let isLoading: Bool
    public let fonts: [GhosttyFontFamily]
    public let error: String?

    public init(
        isLoading: Bool = false,
        fonts: [GhosttyFontFamily] = [],
        error: String? = nil
    ) {
        self.isLoading = isLoading
        self.fonts = fonts
        self.error = error
    }
}

/// Asynchronous state of discovered themes.
public struct ThemesState: Sendable, Equatable {
    public let isLoading: Bool
    public let themes: [GhosttyTheme]
    public let error: String?

    public init(
        isLoading: Bool = false,
        themes: [GhosttyTheme] = [],
        error: String? = nil
    ) {
        self.isLoading = isLoading
        self.themes = themes
        self.error = error
    }
}
