import Foundation

/// Shell integration auto-injection modes supported by Ghostty.
public enum GhosttyShellIntegrationMode: String, CaseIterable, Identifiable, Sendable {
    case detect = "detect"
    case none = "none"
    case zsh = "zsh"
    case bash = "bash"
    case fish = "fish"
    case nushell = "nushell"
    case elvish = "elvish"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .detect: return "Auto-detect (Recommended)"
        case .none: return "Disabled (None)"
        case .zsh: return "Zsh"
        case .bash: return "Bash"
        case .fish: return "Fish"
        case .nushell: return "Nushell"
        case .elvish: return "Elvish"
        }
    }
}

/// Supported individual features for Ghostty `shell-integration-features`.
public enum GhosttyShellFeature: String, CaseIterable, Identifiable, Sendable {
    case cursor = "cursor"
    case sudo = "sudo"
    case title = "title"
    case sshEnv = "ssh-env"
    case sshTerminfo = "ssh-terminfo"
    case path = "path"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .cursor: return "Cursor Shape Management"
        case .sudo: return "Sudo Wrapper (Preserve Terminfo)"
        case .title: return "Automatic Window Title"
        case .sshEnv: return "SSH Environment Compatibility"
        case .sshTerminfo: return "SSH Terminfo Auto-Installation"
        case .path: return "Add Ghostty Binary to PATH"
        }
    }

    public var featureDescription: String {
        switch self {
        case .cursor: return "Sets cursor to a bar at the shell prompt."
        case .sudo: return "Wraps sudo to preserve terminfo for root sessions."
        case .title: return "Reports current directory and command in window title."
        case .sshEnv: return "Propagates TERM and color environment variables over SSH."
        case .sshTerminfo: return "Automatically uploads Ghostty terminfo to remote SSH hosts."
        case .path: return "Ensures the ghostty CLI binary is in the shell PATH."
        }
    }

    /// Whether this feature is enabled by default in Ghostty.
    /// Ghostty default is: `cursor,no-sudo,title,no-ssh-env,no-ssh-terminfo,path`
    public var isDefaultEnabled: Bool {
        switch self {
        case .cursor, .title, .path: return true
        case .sudo, .sshEnv, .sshTerminfo: return false
        }
    }
}

/// Working directory policy for new terminal surfaces.
public enum GhosttyWorkingDirectoryMode: String, CaseIterable, Identifiable, Sendable {
    case inherit = "inherit"
    case home = "home"
    case custom = "custom"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .inherit: return "Inherit (Process / Previous Window)"
        case .home: return "User Home Directory (~)"
        case .custom: return "Custom Directory Path"
        }
    }
}

/// Environment variable entry for Ghostty `env = KEY=VALUE` settings.
public struct GhosttyEnvVariable: Identifiable, Hashable, Sendable {
    public var id: String { key }
    public var key: String
    public var value: String

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }

    /// Formats as `KEY=VALUE` for Ghostty configuration line.
    public var formattedConfigEntry: String {
        "\(key)=\(value)"
    }

    /// Parses from a `KEY=VALUE` string.
    public static func parse(_ raw: String) -> GhosttyEnvVariable? {
        guard let separatorRange = raw.range(of: "=") else { return nil }
        let k = String(raw[..<separatorRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let v = String(raw[separatorRange.upperBound...])
        guard !k.isEmpty else { return nil }
        return GhosttyEnvVariable(key: k, value: v)
    }
}
