import Foundation

extension AppViewModel {
    // MARK: - Typography Settings

    /// Primary font family (first declared `font-family` key in config).
    public var primaryFontFamily: String {
        get {
            currentDocument.allValues(for: "font-family").first ?? "Monaco"
        }
        set {
            let fallbacks = fallbackFontFamilies
            let all = [newValue] + fallbacks
            let isQuoted = all.contains { $0.contains(" ") }
            setRepeatedSettings(key: "font-family", values: all, isQuoted: isQuoted)
        }
    }

    /// Ordered list of fallback font families.
    public var fallbackFontFamilies: [String] {
        get {
            let all = currentDocument.allValues(for: "font-family")
            return all.count > 1 ? Array(all.dropFirst()) : []
        }
        set {
            let primary = primaryFontFamily
            let all = [primary] + newValue
            let isQuoted = all.contains { $0.contains(" ") }
            setRepeatedSettings(key: "font-family", values: all, isQuoted: isQuoted)
        }
    }

    /// Adds a fallback font family to the end of the fallback list.
    public func addFallbackFont(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        var fallbacks = fallbackFontFamilies
        guard !fallbacks.contains(trimmed) else { return }
        fallbacks.append(trimmed)
        fallbackFontFamilies = fallbacks
    }

    /// Removes a fallback font family by index.
    public func removeFallbackFont(at index: Int) {
        var fallbacks = fallbackFontFamilies
        guard fallbacks.indices.contains(index) else { return }
        fallbacks.remove(at: index)
        fallbackFontFamilies = fallbacks
    }

    /// Moves fallback font positions.
    public func moveFallbackFonts(from source: IndexSet, to destination: Int) {
        var fallbacks = fallbackFontFamilies
        fallbacks.move(fromOffsets: source, toOffset: destination)
        fallbackFontFamilies = fallbacks
    }

    /// Font size in points.
    public var fontSize: Double {
        get {
            if let val = currentDocument.effectiveValue(for: "font-size"), let d = Double(val) {
                return d
            }
            return 13.0
        }
        set {
            let formatted = newValue.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(newValue))
                : String(format: "%.1f", newValue)
            updateSetting(key: "font-size", value: formatted)
        }
    }

    /// Whether font thickening is enabled.
    public var fontThicken: Bool {
        get {
            currentDocument.effectiveValue(for: "font-thicken") == "true"
        }
        set {
            updateSetting(key: "font-thicken", value: newValue ? "true" : "false")
        }
    }

    /// Font thickening strength (0...255).
    public var fontThickenStrength: Int {
        get {
            if let val = currentDocument.effectiveValue(for: "font-thicken-strength"), let intVal = Int(val) {
                return min(max(intVal, 0), 255)
            }
            return 255
        }
        set {
            let clamped = min(max(newValue, 0), 255)
            updateSetting(key: "font-thicken-strength", value: "\(clamped)")
        }
    }

    /// Whether programming ligatures are enabled.
    /// In Ghostty, ligatures are enabled by default; setting `font-feature = -calt` disables them.
    public var ligaturesEnabled: Bool {
        get {
            let features = currentDocument.allValues(for: "font-feature")
            for feat in features {
                if feat.contains("-calt") || feat.contains("-liga") {
                    return false
                }
            }
            return true
        }
        set {
            if newValue {
                removeSetting(key: "font-feature")
            } else {
                updateSetting(key: "font-feature", value: "-calt")
            }
        }
    }

    /// Adjustment for cell width (percentage or integer, e.g. "5%" or "2").
    public var adjustCellWidth: String {
        get {
            currentDocument.effectiveValue(for: "adjust-cell-width") ?? ""
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                removeSetting(key: "adjust-cell-width")
            } else {
                updateSetting(key: "adjust-cell-width", value: trimmed)
            }
        }
    }

    /// Adjustment for cell height (percentage or integer, e.g. "10%" or "2").
    public var adjustCellHeight: String {
        get {
            currentDocument.effectiveValue(for: "adjust-cell-height") ?? ""
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                removeSetting(key: "adjust-cell-height")
            } else {
                updateSetting(key: "adjust-cell-height", value: trimmed)
            }
        }
    }

    /// Adjustment for font baseline.
    public var adjustFontBaseline: String {
        get {
            currentDocument.effectiveValue(for: "adjust-font-baseline") ?? ""
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                removeSetting(key: "adjust-font-baseline")
            } else {
                updateSetting(key: "adjust-font-baseline", value: trimmed)
            }
        }
    }
}
