import Foundation

extension AppViewModel {
    // MARK: - Configuration Analysis & Breakdown

    /// Analyzes the in-memory document against the baseline disk document, categorizing managed, unmanaged, and comments.
    public var configBreakdown: ConfigBreakdown {
        var managed: [ManagedSettingItem] = []
        var unmanaged: [UnmanagedSettingItem] = []
        var commentCount = 0
        var blankCount = 0

        for (index, line) in currentDocument.lines.enumerated() {
            let lineNumber = index + 1
            switch line {
            case .assignment(let a):
                if GhosttyManagedKeys.isManaged(key: a.key) {
                    let originalVal = originalDocument?.effectiveValue(for: a.key)
                    let isMod: Bool
                    if let orig = originalVal {
                        isMod = (orig != a.value)
                    } else {
                        // Key is new in current document compared to original
                        isMod = (originalDocument != nil)
                    }

                    managed.append(ManagedSettingItem(
                        key: a.key,
                        value: a.value,
                        originalValue: originalVal,
                        isModified: isMod,
                        category: ManagedKeyCategory.category(for: a.key)
                    ))
                } else {
                    unmanaged.append(UnmanagedSettingItem(
                        lineNumber: lineNumber,
                        key: a.key,
                        value: a.value,
                        rawLine: a.serializedText
                    ))
                }
            case .comment:
                commentCount += 1
            case .blank:
                blankCount += 1
            case .unrecognized:
                break
            }
        }

        return ConfigBreakdown(
            totalLines: currentDocument.lines.count,
            managedItems: managed,
            unmanagedItems: unmanaged,
            commentLineCount: commentCount,
            blankLineCount: blankCount
        )
    }

    /// Formatted line models for the raw read-only preview showing syntax type and diff status.
    public var previewLines: [FormattedPreviewLine] {
        currentDocument.lines.enumerated().map { index, line in
            let lineNumber = index + 1
            let content = line.serializedText

            switch line {
            case .comment:
                return FormattedPreviewLine(
                    lineNumber: lineNumber,
                    content: content,
                    lineType: .comment,
                    isModified: false
                )
            case .blank:
                return FormattedPreviewLine(
                    lineNumber: lineNumber,
                    content: content,
                    lineType: .blank,
                    isModified: false
                )
            case .assignment(let a):
                let isMod: Bool
                if let orig = originalDocument?.effectiveValue(for: a.key) {
                    isMod = (orig != a.value)
                } else {
                    isMod = (originalDocument != nil)
                }

                if GhosttyManagedKeys.isManaged(key: a.key) {
                    return FormattedPreviewLine(
                        lineNumber: lineNumber,
                        content: content,
                        lineType: .managedAssignment(key: a.key, value: a.value),
                        isModified: isMod
                    )
                } else {
                    return FormattedPreviewLine(
                        lineNumber: lineNumber,
                        content: content,
                        lineType: .unmanagedAssignment(key: a.key, value: a.value),
                        isModified: false
                    )
                }
            case .unrecognized:
                return FormattedPreviewLine(
                    lineNumber: lineNumber,
                    content: content,
                    lineType: .unrecognized,
                    isModified: false
                )
            }
        }
    }

    // MARK: - Key Reversion & Reset Actions

    /// Reverts an individual setting back to its saved baseline value on disk.
    public func revertSetting(key: String) {
        if let originalValue = originalDocument?.effectiveValue(for: key) {
            updateSetting(key: key, value: originalValue)
        } else {
            removeSetting(key: key)
        }
    }

    /// Removes an individual managed setting completely from the configuration.
    public func removeManagedSetting(key: String) {
        removeSetting(key: key)
    }

    // MARK: - Section Change Tracking

    /// Returns the number of modified settings within a specific navigation section.
    public func modifiedCount(for section: NavigationSection) -> Int {
        guard isDirty else { return 0 }
        let breakdown = configBreakdown
        switch section {
        case .general:
            return 0
        case .typography:
            return breakdown.managedItems.filter { $0.category == .typography && $0.isModified }.count
        case .persian:
            return breakdown.managedItems.filter {
                ($0.key == "adjust-cell-height" || $0.key == "adjust-font-baseline" || $0.key == "font-thicken" || $0.key == "font-family") && $0.isModified
            }.count
        case .appearance:
            return breakdown.managedItems.filter { $0.category == .appearance && $0.isModified }.count
        case .window:
            return breakdown.managedItems.filter { $0.category == .window && $0.isModified }.count
        case .shell:
            return breakdown.managedItems.filter { $0.category == .shell && $0.isModified }.count
        case .config:
            return breakdown.modifiedCount
        }
    }

    /// Checks whether a specific navigation section has in-memory modifications.
    public func hasModifications(for section: NavigationSection) -> Bool {
        modifiedCount(for: section) > 0
    }

    // MARK: - Change Tracking & Diff Engine

    /// Aggregated diff report comparing baseline and current in-memory configurations.
    public var pendingDiff: GhosttyConfigDiff {
        ConfigChangeTracker.computeDiff(original: originalDocument, current: currentDocument)
    }

    /// Reverts an individual change entry back to its baseline value.
    public func revertChange(_ entry: ConfigChangeEntry) {
        ConfigChangeTracker.revert(entry: entry, on: self)
    }
}
