import Foundation

/// macOS titlebar styles supported by Ghostty.
public enum MacOSTitlebarStyle: String, CaseIterable, Identifiable, Sendable {
    case transparent = "transparent"
    case native = "native"
    case tabs = "tabs"
    case hidden = "hidden"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .transparent: return "Transparent (Modern / Blended)"
        case .native: return "Native (Standard macOS Titlebar)"
        case .tabs: return "Tabs (Integrated Tabbar)"
        case .hidden: return "Hidden (No Titlebar)"
        }
    }
}

/// Window state restoration policy supported by Ghostty on macOS.
public enum WindowSaveStatePolicy: String, CaseIterable, Identifiable, Sendable {
    case defaultPolicy = "default"
    case always = "always"
    case never = "never"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .defaultPolicy: return "Default (System Standard)"
        case .always: return "Always Restore Windows"
        case .never: return "Never Restore Windows"
        }
    }
}

/// Window theme appearance mode.
public enum WindowThemeMode: String, CaseIterable, Identifiable, Sendable {
    case auto = "auto"
    case system = "system"
    case dark = "dark"
    case light = "light"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .auto: return "Auto (Match Terminal Theme)"
        case .system: return "System (Follow macOS Dark/Light)"
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }
}
