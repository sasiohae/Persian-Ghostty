import Foundation

extension AppViewModel {
    // MARK: - Appearance Settings

    /// Active theme name (e.g., "3024 Night", "Aizen Dark").
    public var theme: String {
        get {
            currentDocument.effectiveValue(for: "theme") ?? ""
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                removeSetting(key: "theme")
            } else {
                updateSetting(key: "theme", value: trimmed, isQuoted: trimmed.contains(" "))
            }
        }
    }

    /// Background opacity level from 0.0 (transparent) to 1.0 (fully opaque).
    public var backgroundOpacity: Double {
        get {
            if let val = currentDocument.effectiveValue(for: "background-opacity"), let d = Double(val) {
                return min(max(d, 0.0), 1.0)
            }
            return 1.0
        }
        set {
            let clamped = min(max(newValue, 0.0), 1.0)
            let formatted = clamped == 1.0 ? "1" : (clamped == 0.0 ? "0" : String(format: "%.2f", clamped))
            updateSetting(key: "background-opacity", value: formatted)
        }
    }

    /// Background blur style or raw configuration value.
    public var backgroundBlur: String {
        get {
            currentDocument.effectiveValue(for: "background-blur") ?? "false"
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed == "false" {
                updateSetting(key: "background-blur", value: "false")
            } else {
                updateSetting(key: "background-blur", value: trimmed)
            }
        }
    }

    /// Typed background blur style.
    public var blurStyle: GhosttyBlurStyle {
        get {
            GhosttyBlurStyle(rawValue: backgroundBlur) ?? .disabled
        }
        set {
            backgroundBlur = newValue.rawValue
        }
    }

    /// Terminal cursor rendering style (block, bar, underline, block_hollow).
    public var cursorStyle: GhosttyCursorStyle {
        get {
            if let val = currentDocument.effectiveValue(for: "cursor-style"),
               let style = GhosttyCursorStyle(rawValue: val) {
                return style
            }
            return .block
        }
        set {
            updateSetting(key: "cursor-style", value: newValue.rawValue)
        }
    }

    /// Cursor blinking state: nil (Ghostty default), true, or false.
    public var cursorBlink: Bool? {
        get {
            guard let val = currentDocument.effectiveValue(for: "cursor-style-blink") else {
                return nil
            }
            if val == "true" { return true }
            if val == "false" { return false }
            return nil
        }
        set {
            if let newValue = newValue {
                updateSetting(key: "cursor-style-blink", value: newValue ? "true" : "false")
            } else {
                removeSetting(key: "cursor-style-blink")
            }
        }
    }

    /// Custom cursor color (e.g. #ffffff).
    public var cursorColor: String {
        get {
            currentDocument.effectiveValue(for: "cursor-color") ?? ""
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                removeSetting(key: "cursor-color")
            } else {
                updateSetting(key: "cursor-color", value: trimmed)
            }
        }
    }

    /// Custom background color override.
    public var customBackground: String {
        get {
            currentDocument.effectiveValue(for: "background") ?? ""
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                removeSetting(key: "background")
            } else {
                updateSetting(key: "background", value: trimmed)
            }
        }
    }

    /// Custom foreground color override.
    public var customForeground: String {
        get {
            currentDocument.effectiveValue(for: "foreground") ?? ""
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                removeSetting(key: "foreground")
            } else {
                updateSetting(key: "foreground", value: trimmed)
            }
        }
    }
}
