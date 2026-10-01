import Foundation

/// Defines the source domain or scope of a Ghostty configuration path.
public enum GhosttyConfigScope: String, Sendable, CaseIterable, Equatable {
    /// XDG-compliant configuration directory ($XDG_CONFIG_HOME or ~/.config).
    case xdg = "XDG"
    /// macOS-specific Application Support directory (~/Library/Application Support/com.mitchellh.ghostty).
    case macOS = "macOS"
}

/// Represents a candidate or discovered Ghostty configuration file path on the filesystem.
public struct GhosttyConfigPath: Sendable, Equatable, Identifiable {
    public var id: String { url.path }

    /// The file URL for this configuration location.
    public let url: URL

    /// The configuration scope (XDG or macOS Application Support).
    public let scope: GhosttyConfigScope

    /// Whether this file currently exists on disk.
    public let exists: Bool

    /// Precedence order ranking (lower number = loaded earlier; higher number = loaded later / higher precedence).
    public let precedenceOrder: Int

    public init(url: URL, scope: GhosttyConfigScope, exists: Bool, precedenceOrder: Int) {
        self.url = url
        self.scope = scope
        self.exists = exists
        self.precedenceOrder = precedenceOrder
    }
}
