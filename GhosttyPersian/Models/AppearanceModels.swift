import Foundation

/// Terminal cursor rendering styles supported by Ghostty.
public enum GhosttyCursorStyle: String, CaseIterable, Identifiable, Sendable {
    case block = "block"
    case bar = "bar"
    case underline = "underline"
    case blockHollow = "block_hollow"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .block: return "Block (Filled)"
        case .bar: return "Bar (Beam)"
        case .underline: return "Underline"
        case .blockHollow: return "Hollow Block"
        }
    }
}

/// macOS glass and background blur styles supported by Ghostty.
public enum GhosttyBlurStyle: String, CaseIterable, Identifiable, Sendable {
    case disabled = "false"
    case enabled = "true"
    case macosGlassRegular = "macos-glass-regular"
    case macosGlassClear = "macos-glass-clear"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .disabled: return "Disabled"
        case .enabled: return "Standard Blur"
        case .macosGlassRegular: return "macOS Glass (Regular)"
        case .macosGlassClear: return "macOS Glass (Clear)"
        }
    }
}
