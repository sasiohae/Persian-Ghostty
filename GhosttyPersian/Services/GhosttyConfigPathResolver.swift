import Foundation

/// Service responsible for discovering Ghostty configuration files according to official precedence rules.
public struct GhosttyConfigPathResolver: Sendable {
    public let homeDirectory: URL
    public let environment: [String: String]
    public let fileExists: @Sendable (URL) -> Bool

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileExists: @escaping @Sendable (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) {
        self.homeDirectory = homeDirectory
        self.environment = environment
        self.fileExists = fileExists
    }

    /// Returns the base XDG configuration directory URL.
    public var xdgConfigDirectory: URL {
        if let xdgHome = environment["XDG_CONFIG_HOME"], !xdgHome.trimmingCharacters(in: .whitespaces).isEmpty {
            return URL(fileURLWithPath: xdgHome)
        }
        return homeDirectory.appendingPathComponent(".config", isDirectory: true)
    }

    /// Returns the macOS Application Support configuration directory URL for Ghostty.
    public var macOSConfigDirectory: URL {
        homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("com.mitchellh.ghostty", isDirectory: true)
    }

    /// All potential configuration file candidates in their loading order.
    ///
    /// Precedence order:
    /// 1. XDG `config.ghostty`
    /// 2. XDG `config`
    /// 3. macOS Application Support `config.ghostty`
    /// 4. macOS Application Support `config` (highest precedence)
    public func candidatePaths() -> [GhosttyConfigPath] {
        let xdgDir = xdgConfigDirectory.appendingPathComponent("ghostty", isDirectory: true)
        let macDir = macOSConfigDirectory

        let candidates: [(URL, GhosttyConfigScope, Int)] = [
            (xdgDir.appendingPathComponent("config.ghostty", isDirectory: false), .xdg, 1),
            (xdgDir.appendingPathComponent("config", isDirectory: false), .xdg, 2),
            (macDir.appendingPathComponent("config.ghostty", isDirectory: false), .macOS, 3),
            (macDir.appendingPathComponent("config", isDirectory: false), .macOS, 4)
        ]

        return candidates.map { url, scope, order in
            GhosttyConfigPath(
                url: url,
                scope: scope,
                exists: fileExists(url),
                precedenceOrder: order
            )
        }
    }

    /// Returns only configuration candidates that actually exist on the filesystem, ordered by precedence.
    public func existingPaths() -> [GhosttyConfigPath] {
        candidatePaths().filter(\.exists)
    }

    /// Returns the currently effective configuration path based on highest precedence.
    ///
    /// If both XDG and macOS configurations exist, the macOS configuration takes precedence.
    /// If multiple files exist within the same scope, the standard `config` takes precedence over `config.ghostty`.
    public func effectiveConfigurationPath() -> GhosttyConfigPath? {
        existingPaths().max(by: { $0.precedenceOrder < $1.precedenceOrder })
    }

    /// The recommended default path for saving new macOS configuration if none exists.
    public var defaultRecommendedPath: URL {
        macOSConfigDirectory.appendingPathComponent("config", isDirectory: false)
    }
}
