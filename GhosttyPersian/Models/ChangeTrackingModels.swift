import Foundation

/// Classification of a configuration change between baseline disk configuration and current working document.
public enum ChangeKind: String, Sendable, CaseIterable, Identifiable {
    case added = "Added"
    case modified = "Modified"
    case removed = "Removed"
    case untouched = "Untouched"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .added: return "plus.circle.fill"
        case .modified: return "pencil.circle.fill"
        case .removed: return "minus.circle.fill"
        case .untouched: return "checkmark.circle"
        }
    }
}

/// Category of the configuration line being tracked.
public enum SettingTypeCategory: String, Sendable, CaseIterable, Identifiable {
    case managed = "Managed"
    case unmanaged = "Custom / Protected"
    case comment = "Comment"
    case blank = "Whitespace"

    public var id: String { rawValue }
}

/// Detailed item describing a single configuration key or line's change status.
public struct ConfigChangeEntry: Identifiable, Sendable, Equatable {
    public var id: String {
        if !key.isEmpty {
            return key
        }
        return "line-\(lineNumber ?? 0)"
    }

    /// The configuration key (e.g., "font-size", "theme").
    public let key: String

    /// Baseline value loaded from disk (or nil if newly added).
    public let oldValue: String?

    /// In-memory value in the working document (or nil if deleted).
    public let newValue: String?

    /// The type of change (added, modified, removed, untouched).
    public let changeKind: ChangeKind

    /// Classification of the setting (managed, custom/unmanaged, comment, blank).
    public let category: SettingTypeCategory

    /// 1-based line number in the current document (if present).
    public let lineNumber: Int?

    public init(
        key: String,
        oldValue: String?,
        newValue: String?,
        changeKind: ChangeKind,
        category: SettingTypeCategory,
        lineNumber: Int? = nil
    ) {
        self.key = key
        self.oldValue = oldValue
        self.newValue = newValue
        self.changeKind = changeKind
        self.category = category
        self.lineNumber = lineNumber
    }

    /// Whether this entry represents an actual change compared to baseline.
    public var isChanged: Bool {
        changeKind != .untouched
    }
}

/// Aggregated diff report comparing baseline and current in-memory configurations.
public struct GhosttyConfigDiff: Sendable, Equatable {
    /// All entries, including untouched and preserved lines.
    public let allEntries: [ConfigChangeEntry]

    /// Only changed entries (added, modified, removed).
    public var changedEntries: [ConfigChangeEntry] {
        allEntries.filter(\.isChanged)
    }

    /// Number of added settings.
    public let addedCount: Int

    /// Number of modified settings.
    public let modifiedCount: Int

    /// Number of removed settings.
    public let removedCount: Int

    /// Number of untouched managed settings.
    public let untouchedManagedCount: Int

    /// Number of preserved custom/unmanaged lines and comments.
    public let preservedUnmanagedCount: Int

    public init(
        allEntries: [ConfigChangeEntry],
        addedCount: Int,
        modifiedCount: Int,
        removedCount: Int,
        untouchedManagedCount: Int,
        preservedUnmanagedCount: Int
    ) {
        self.allEntries = allEntries
        self.addedCount = addedCount
        self.modifiedCount = modifiedCount
        self.removedCount = removedCount
        self.untouchedManagedCount = untouchedManagedCount
        self.preservedUnmanagedCount = preservedUnmanagedCount
    }

    /// Whether there are any pending in-memory modifications.
    public var hasChanges: Bool {
        totalChangesCount > 0
    }

    /// Total count of all changed settings.
    public var totalChangesCount: Int {
        addedCount + modifiedCount + removedCount
    }
}
