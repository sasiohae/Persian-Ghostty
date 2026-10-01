import Foundation

/// Role of the Persian font in the preset.
public enum PersianFontRole: String, CaseIterable, Identifiable, Sendable {
    case fallback = "Fallback (Recommended for Programming)"
    case primary = "Primary Font"

    public var id: String { rawValue }
}

/// A cohesive, verified Ghostty configuration preset tailored for Persian terminal users.
public struct PersianPreset: Identifiable, Sendable, Equatable, Hashable {
    public var id: String { name }

    /// Human-readable preset name.
    public let name: String

    /// Description of the preset's purpose and adjustments.
    public let description: String

    /// Whether the Persian font is configured as fallback or primary.
    public let fontRole: PersianFontRole

    /// Persian typeface to apply (defaults to Vazirmatn).
    public let persianFontName: String

    /// Vertical cell height adjustment to prevent clipping of Persian dots and descenders.
    public let adjustCellHeight: String

    /// Font baseline vertical shift.
    public let adjustFontBaseline: String

    /// Whether to thicken font rendering for crisp glyph strokes.
    public let fontThicken: Bool

    /// Horizontal window padding in points.
    public let windowPaddingX: Int

    /// Vertical window padding in points.
    public let windowPaddingY: Int

    /// Whether to balance horizontal padding across both edges.
    public let windowPaddingBalance: Bool

    /// Terminal cursor shape.
    public let cursorStyle: String

    /// Whether the cursor blinks.
    public let cursorBlink: Bool

    /// Whether to hide the mouse cursor while typing.
    public let mouseHideWhileTyping: Bool

    public init(
        name: String,
        description: String,
        fontRole: PersianFontRole = .fallback,
        persianFontName: String = "Vazirmatn",
        adjustCellHeight: String = "15%",
        adjustFontBaseline: String = "1",
        fontThicken: Bool = true,
        windowPaddingX: Int = 10,
        windowPaddingY: Int = 8,
        windowPaddingBalance: Bool = true,
        cursorStyle: String = "bar",
        cursorBlink: Bool = true,
        mouseHideWhileTyping: Bool = true
    ) {
        self.name = name
        self.description = description
        self.fontRole = fontRole
        self.persianFontName = persianFontName
        self.adjustCellHeight = adjustCellHeight
        self.adjustFontBaseline = adjustFontBaseline
        self.fontThicken = fontThicken
        self.windowPaddingX = windowPaddingX
        self.windowPaddingY = windowPaddingY
        self.windowPaddingBalance = windowPaddingBalance
        self.cursorStyle = cursorStyle
        self.cursorBlink = cursorBlink
        self.mouseHideWhileTyping = mouseHideWhileTyping
    }

    /// Standard preset: keeps existing primary coding font and injects Vazirmatn as fallback with balanced metrics.
    public static let standard = PersianPreset(
        name: "Standard Developer (Fallback Vazirmatn)",
        description: "Recommended for programming: preserves your current coding font for Latin/ASCII code and adds Vazirmatn as fallback, expanding vertical cell height to 15% with balanced padding.",
        fontRole: .fallback,
        persianFontName: "Vazirmatn",
        adjustCellHeight: "15%",
        adjustFontBaseline: "1",
        fontThicken: true,
        windowPaddingX: 10,
        windowPaddingY: 8,
        windowPaddingBalance: true,
        cursorStyle: "bar",
        cursorBlink: true,
        mouseHideWhileTyping: true
    )

    /// Full Persian preset: sets Vazirmatn directly as the primary terminal font.
    public static let fullPersian = PersianPreset(
        name: "Full Persian (Vazirmatn Primary)",
        description: "Sets Vazirmatn as the primary terminal typeface across all terminal characters, with 15% cell expansion and comfortable padding.",
        fontRole: .primary,
        persianFontName: "Vazirmatn",
        adjustCellHeight: "15%",
        adjustFontBaseline: "1",
        fontThicken: true,
        windowPaddingX: 10,
        windowPaddingY: 8,
        windowPaddingBalance: true,
        cursorStyle: "bar",
        cursorBlink: true,
        mouseHideWhileTyping: true
    )

    /// Compact preset: lighter metrics and tighter cell spacing while maintaining Persian legibility.
    public static let compact = PersianPreset(
        name: "Compact Persian",
        description: "Tighter terminal geometry: 10% cell height adjustment with minimal window padding.",
        fontRole: .fallback,
        persianFontName: "Vazirmatn",
        adjustCellHeight: "10%",
        adjustFontBaseline: "1",
        fontThicken: false,
        windowPaddingX: 6,
        windowPaddingY: 4,
        windowPaddingBalance: true,
        cursorStyle: "bar",
        cursorBlink: true,
        mouseHideWhileTyping: true
    )

    /// Available built-in preset options.
    public static let allPresets: [PersianPreset] = [.standard, .fullPersian, .compact]
}

/// Represents an individual configuration key change calculated for a preset preview.
public struct PresetChangeItem: Identifiable, Sendable, Equatable {
    public var id: String { key }

    /// The Ghostty configuration key.
    public let key: String

    /// Current effective value in memory (or nil if unset).
    public let currentValue: String?

    /// Proposed value that will be set by the preset.
    public let proposedValue: String

    /// Whether applying the preset will modify the current document value.
    public var isModified: Bool {
        currentValue != proposedValue
    }

    public init(key: String, currentValue: String?, proposedValue: String) {
        self.key = key
        self.currentValue = currentValue
        self.proposedValue = proposedValue
    }
}
