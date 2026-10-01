import Foundation

extension AppViewModel {
    // MARK: - Window Settings

    /// The style of the macOS titlebar (transparent, native, tabs, hidden).
    public var macosTitlebarStyle: MacOSTitlebarStyle {
        get {
            if let val = currentDocument.effectiveValue(for: "macos-titlebar-style"),
               let style = MacOSTitlebarStyle(rawValue: val) {
                return style
            }
            return .transparent
        }
        set {
            updateSetting(key: "macos-titlebar-style", value: newValue.rawValue)
        }
    }

    /// Whether the proxy icon in the macOS titlebar is visible.
    public var macosTitlebarProxyIcon: Bool {
        get {
            currentDocument.effectiveValue(for: "macos-titlebar-proxy-icon") != "hidden"
        }
        set {
            updateSetting(key: "macos-titlebar-proxy-icon", value: newValue ? "visible" : "hidden")
        }
    }

    /// Whether window buttons (traffic lights) are visible in the macOS titlebar.
    public var macosWindowButtons: Bool {
        get {
            currentDocument.effectiveValue(for: "macos-window-buttons") != "hidden"
        }
        set {
            updateSetting(key: "macos-window-buttons", value: newValue ? "visible" : "hidden")
        }
    }

    /// Whether window decorations are enabled (auto) or disabled (none).
    public var windowDecorations: Bool {
        get {
            currentDocument.effectiveValue(for: "window-decoration") != "none"
        }
        set {
            updateSetting(key: "window-decoration", value: newValue ? "auto" : "none")
        }
    }

    /// Horizontal inner padding in pixels/points.
    public var windowPaddingX: Int {
        get {
            if let val = currentDocument.effectiveValue(for: "window-padding-x"), let intVal = Int(val) {
                return max(intVal, 0)
            }
            return 2
        }
        set {
            let clamped = max(newValue, 0)
            updateSetting(key: "window-padding-x", value: "\(clamped)")
        }
    }

    /// Vertical inner padding in pixels/points.
    public var windowPaddingY: Int {
        get {
            if let val = currentDocument.effectiveValue(for: "window-padding-y"), let intVal = Int(val) {
                return max(intVal, 0)
            }
            return 2
        }
        set {
            let clamped = max(newValue, 0)
            updateSetting(key: "window-padding-y", value: "\(clamped)")
        }
    }

    /// Whether to balance horizontal padding across both edges evenly.
    public var windowPaddingBalance: Bool {
        get {
            currentDocument.effectiveValue(for: "window-padding-balance") == "true"
        }
        set {
            updateSetting(key: "window-padding-balance", value: newValue ? "true" : "false")
        }
    }

    /// Window restoration policy on macOS (default, always, never).
    public var windowSaveState: WindowSaveStatePolicy {
        get {
            if let val = currentDocument.effectiveValue(for: "window-save-state"),
               let policy = WindowSaveStatePolicy(rawValue: val) {
                return policy
            }
            return .defaultPolicy
        }
        set {
            updateSetting(key: "window-save-state", value: newValue.rawValue)
        }
    }

    /// Whether the window resizes in discrete cell increments rather than pixel steps.
    public var windowStepResize: Bool {
        get {
            currentDocument.effectiveValue(for: "window-step-resize") == "true"
        }
        set {
            updateSetting(key: "window-step-resize", value: newValue ? "true" : "false")
        }
    }

    /// Window titlebar and frame theme.
    public var windowTheme: WindowThemeMode {
        get {
            if let val = currentDocument.effectiveValue(for: "window-theme"),
               let mode = WindowThemeMode(rawValue: val) {
                return mode
            }
            return .auto
        }
        set {
            updateSetting(key: "window-theme", value: newValue.rawValue)
        }
    }

    /// Whether non-native macOS fullscreen is enabled.
    public var macosNonNativeFullscreen: Bool {
        get {
            currentDocument.effectiveValue(for: "macos-non-native-fullscreen") == "true"
        }
        set {
            updateSetting(key: "macos-non-native-fullscreen", value: newValue ? "true" : "false")
        }
    }
}
