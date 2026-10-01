import Foundation
import SwiftUI

/// Catalog of all Ghostty configuration keys managed across Ghostty Persian settings views.
public enum GhosttyManagedKeys: Sendable {
    public static let all: Set<String> = [
        // Typography
        "font-family",
        "font-size",
        "font-thicken",
        "font-feature",
        "adjust-cell-width",
        "adjust-cell-height",
        "adjust-font-baseline",

        // Appearance
        "theme",
        "background-opacity",
        "background-blur",
        "cursor-style",
        "cursor-style-blink",
        "cursor-opacity",
        "cursor-color",
        "cursor-text",
        "mouse-hide-while-typing",
        "window-decoration",

        // Window & macOS
        "macos-titlebar-style",
        "macos-window-buttons",
        "macos-titlebar-proxy-icon",
        "window-padding-x",
        "window-padding-y",
        "window-padding-balance",
        "window-save-state",
        "window-step-resize",
        "window-theme",
        "macos-non-native-fullscreen",

        // Shell
        "command",
        "shell-integration",
        "shell-integration-features",
        "working-directory",
        "window-inherit-working-directory",
        "tab-inherit-working-directory",
        "term",
        "env"
    ]

    public static func isManaged(key: String) -> Bool {
        all.contains(key)
    }
}

/// Logical categorizer for managed Ghostty keys.
public enum ManagedKeyCategory: String, CaseIterable, Sendable, Identifiable {
    case typography = "Typography"
    case appearance = "Appearance"
    case window = "Window"
    case shell = "Shell"
    case other = "Other"

    public var id: String { rawValue }

    public static func category(for key: String) -> ManagedKeyCategory {
        switch key {
        case "font-family", "font-size", "font-thicken", "font-feature", "adjust-cell-width", "adjust-cell-height", "adjust-font-baseline":
            return .typography
        case "theme", "background-opacity", "background-blur", "cursor-style", "cursor-style-blink", "cursor-opacity", "cursor-color", "cursor-text", "mouse-hide-while-typing":
            return .appearance
        case "macos-titlebar-style", "macos-window-buttons", "macos-titlebar-proxy-icon", "window-decoration", "window-padding-x", "window-padding-y", "window-padding-balance", "window-save-state", "window-step-resize", "window-theme", "macos-non-native-fullscreen":
            return .window
        case "command", "shell-integration", "shell-integration-features", "working-directory", "window-inherit-working-directory", "tab-inherit-working-directory", "term", "env":
            return .shell
        default:
            return .other
        }
    }
}

/// Represents an item in the managed settings breakdown.
public struct ManagedSettingItem: Identifiable, Sendable, Equatable {
    public var id: String { key }
    public let key: String
    public let value: String
    public let originalValue: String?
    public let isModified: Bool
    public let category: ManagedKeyCategory

    public init(
        key: String,
        value: String,
        originalValue: String? = nil,
        isModified: Bool = false,
        category: ManagedKeyCategory = .other
    ) {
        self.key = key
        self.value = value
        self.originalValue = originalValue
        self.isModified = isModified
        self.category = category
    }
}

/// Represents an unmanaged/custom line preserved verbatim in the configuration.
public struct UnmanagedSettingItem: Identifiable, Sendable, Equatable {
    public var id: String { "\(lineNumber):\(key)" }
    public let lineNumber: Int
    public let key: String
    public let value: String
    public let rawLine: String

    public init(lineNumber: Int, key: String, value: String, rawLine: String) {
        self.lineNumber = lineNumber
        self.key = key
        self.value = value
        self.rawLine = rawLine
    }
}

/// Detailed breakdown of the configuration document content.
public struct ConfigBreakdown: Sendable, Equatable {
    public let totalLines: Int
    public let managedItems: [ManagedSettingItem]
    public let unmanagedItems: [UnmanagedSettingItem]
    public let commentLineCount: Int
    public let blankLineCount: Int

    public init(
        totalLines: Int,
        managedItems: [ManagedSettingItem],
        unmanagedItems: [UnmanagedSettingItem],
        commentLineCount: Int,
        blankLineCount: Int
    ) {
        self.totalLines = totalLines
        self.managedItems = managedItems
        self.unmanagedItems = unmanagedItems
        self.commentLineCount = commentLineCount
        self.blankLineCount = blankLineCount
    }

    public var managedCount: Int { managedItems.count }
    public var unmanagedCount: Int { unmanagedItems.count }
    public var modifiedCount: Int { managedItems.filter(\.isModified).count }
}

/// Representation of a line in the raw configuration preview with diff and syntax info.
public struct FormattedPreviewLine: Identifiable, Sendable, Equatable {
    public var id: Int { lineNumber }
    public let lineNumber: Int
    public let content: String
    public let lineType: PreviewLineType
    public let isModified: Bool

    public init(lineNumber: Int, content: String, lineType: PreviewLineType, isModified: Bool) {
        self.lineNumber = lineNumber
        self.content = content
        self.lineType = lineType
        self.isModified = isModified
    }
}

public enum PreviewLineType: Sendable, Equatable {
    case comment
    case blank
    case managedAssignment(key: String, value: String)
    case unmanagedAssignment(key: String, value: String)
    case unrecognized
}
