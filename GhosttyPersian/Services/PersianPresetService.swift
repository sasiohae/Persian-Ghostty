import Foundation

/// Protocol governing Persian preset calculations and non-destructive application.
public protocol PersianPresetServicing: Sendable {
    /// Computes which configuration keys will be updated, their current values, and their proposed values.
    func previewChanges(for preset: PersianPreset, on document: GhosttyConfigDocument) -> [PresetChangeItem]

    /// Non-destructively applies the preset to the in-memory document, updating only managed keys.
    @discardableResult
    func apply(preset: PersianPreset, to document: inout GhosttyConfigDocument) -> [PresetChangeItem]
}

/// Service implementing safe, non-destructive application of curated Persian presets.
public struct PersianPresetService: PersianPresetServicing {
    public init() {}

    public func previewChanges(for preset: PersianPreset, on document: GhosttyConfigDocument) -> [PresetChangeItem] {
        var items: [PresetChangeItem] = []

        // 1. Font Family
        let currentFonts = document.allValues(for: "font-family")
        let currentFontSummary = currentFonts.isEmpty ? nil : currentFonts.joined(separator: " -> ")
        let proposedFontSummary: String

        switch preset.fontRole {
        case .primary:
            proposedFontSummary = preset.persianFontName
        case .fallback:
            let primary = currentFonts.first ?? "Monaco"
            var fallbacks = Array(currentFonts.dropFirst())
            if !fallbacks.contains(preset.persianFontName) {
                fallbacks.append(preset.persianFontName)
            }
            let all = [primary] + fallbacks
            proposedFontSummary = all.joined(separator: " -> ")
        }

        items.append(PresetChangeItem(
            key: "font-family",
            currentValue: currentFontSummary,
            proposedValue: proposedFontSummary
        ))

        // 2. Metrics & Diacritic Clipping Prevention
        items.append(PresetChangeItem(
            key: "adjust-cell-height",
            currentValue: document.effectiveValue(for: "adjust-cell-height"),
            proposedValue: preset.adjustCellHeight
        ))

        items.append(PresetChangeItem(
            key: "adjust-font-baseline",
            currentValue: document.effectiveValue(for: "adjust-font-baseline"),
            proposedValue: preset.adjustFontBaseline
        ))

        items.append(PresetChangeItem(
            key: "font-thicken",
            currentValue: document.effectiveValue(for: "font-thicken"),
            proposedValue: preset.fontThicken ? "true" : "false"
        ))

        // 3. Window Padding & Geometry
        items.append(PresetChangeItem(
            key: "window-padding-x",
            currentValue: document.effectiveValue(for: "window-padding-x"),
            proposedValue: "\(preset.windowPaddingX)"
        ))

        items.append(PresetChangeItem(
            key: "window-padding-y",
            currentValue: document.effectiveValue(for: "window-padding-y"),
            proposedValue: "\(preset.windowPaddingY)"
        ))

        items.append(PresetChangeItem(
            key: "window-padding-balance",
            currentValue: document.effectiveValue(for: "window-padding-balance"),
            proposedValue: preset.windowPaddingBalance ? "true" : "false"
        ))

        // 4. Cursor & Typing Experience
        items.append(PresetChangeItem(
            key: "cursor-style",
            currentValue: document.effectiveValue(for: "cursor-style"),
            proposedValue: preset.cursorStyle
        ))

        items.append(PresetChangeItem(
            key: "cursor-style-blink",
            currentValue: document.effectiveValue(for: "cursor-style-blink"),
            proposedValue: preset.cursorBlink ? "true" : "false"
        ))

        items.append(PresetChangeItem(
            key: "mouse-hide-while-typing",
            currentValue: document.effectiveValue(for: "mouse-hide-while-typing"),
            proposedValue: preset.mouseHideWhileTyping ? "true" : "false"
        ))

        return items
    }

    @discardableResult
    public func apply(preset: PersianPreset, to document: inout GhosttyConfigDocument) -> [PresetChangeItem] {
        let changes = previewChanges(for: preset, on: document)

        // 1. Font Family
        let currentFonts = document.allValues(for: "font-family")
        switch preset.fontRole {
        case .primary:
            document.setRepeatedValues(
                key: "font-family",
                values: [preset.persianFontName],
                isQuoted: preset.persianFontName.contains(" ")
            )
        case .fallback:
            let primary = currentFonts.first ?? "Monaco"
            var fallbacks = Array(currentFonts.dropFirst())
            if !fallbacks.contains(preset.persianFontName) {
                fallbacks.append(preset.persianFontName)
            }
            let cleanedPrimary = (primary == preset.persianFontName) ? "Monaco" : primary
            let all = [cleanedPrimary] + fallbacks.filter { $0 != cleanedPrimary }
            let isQuoted = all.contains { $0.contains(" ") }
            document.setRepeatedValues(key: "font-family", values: all, isQuoted: isQuoted)
        }

        // 2. Metrics & Diacritic Clipping Prevention
        document.setValue(key: "adjust-cell-height", value: preset.adjustCellHeight)
        document.setValue(key: "adjust-font-baseline", value: preset.adjustFontBaseline)
        document.setValue(key: "font-thicken", value: preset.fontThicken ? "true" : "false")

        // 3. Window Padding & Geometry
        document.setValue(key: "window-padding-x", value: "\(preset.windowPaddingX)")
        document.setValue(key: "window-padding-y", value: "\(preset.windowPaddingY)")
        document.setValue(key: "window-padding-balance", value: preset.windowPaddingBalance ? "true" : "false")

        // 4. Cursor & Typing Experience
        document.setValue(key: "cursor-style", value: preset.cursorStyle)
        document.setValue(key: "cursor-style-blink", value: preset.cursorBlink ? "true" : "false")
        document.setValue(key: "mouse-hide-while-typing", value: preset.mouseHideWhileTyping ? "true" : "false")

        return changes
    }
}
