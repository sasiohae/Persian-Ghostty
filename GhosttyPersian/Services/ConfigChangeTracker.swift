import Foundation

/// Engine responsible for computing non-destructive semantic diffs and executing individual reverts.
public struct ConfigChangeTracker: Sendable {
    public init() {}

    /// Computes a comprehensive configuration diff between original disk state and current in-memory edits.
    public static func computeDiff(
        original: GhosttyConfigDocument?,
        current: GhosttyConfigDocument
    ) -> GhosttyConfigDiff {
        var entries: [ConfigChangeEntry] = []
        var processedKeys = Set<String>()

        var addedCount = 0
        var modifiedCount = 0
        var removedCount = 0
        var untouchedManagedCount = 0
        var preservedUnmanagedCount = 0

        // 1. Process all lines in the current working document
        for (index, line) in current.lines.enumerated() {
            let lineNumber = index + 1
            switch line {
            case .assignment(let a):
                let key = a.key
                guard !processedKeys.contains(key) else { continue }
                processedKeys.insert(key)

                let currentVal: String
                let originalVal: String?

                if key == "font-family" || key == "env" {
                    currentVal = current.allValues(for: key).joined(separator: " -> ")
                    let origValues = original?.allValues(for: key) ?? []
                    originalVal = origValues.isEmpty ? nil : origValues.joined(separator: " -> ")
                } else {
                    currentVal = current.effectiveValue(for: key) ?? a.value
                    originalVal = original?.effectiveValue(for: key)
                }

                let isManaged = GhosttyManagedKeys.isManaged(key: key)
                let category: SettingTypeCategory = isManaged ? .managed : .unmanaged

                if let orig = originalVal {
                    if orig != currentVal {
                        entries.append(ConfigChangeEntry(
                            key: key,
                            oldValue: orig,
                            newValue: currentVal,
                            changeKind: .modified,
                            category: category,
                            lineNumber: lineNumber
                        ))
                        modifiedCount += 1
                    } else {
                        entries.append(ConfigChangeEntry(
                            key: key,
                            oldValue: orig,
                            newValue: currentVal,
                            changeKind: .untouched,
                            category: category,
                            lineNumber: lineNumber
                        ))
                        if isManaged {
                            untouchedManagedCount += 1
                        } else {
                            preservedUnmanagedCount += 1
                        }
                    }
                } else {
                    // Key was added (did not exist in original disk document)
                    if original != nil {
                        entries.append(ConfigChangeEntry(
                            key: key,
                            oldValue: nil,
                            newValue: currentVal,
                            changeKind: .added,
                            category: category,
                            lineNumber: lineNumber
                        ))
                        addedCount += 1
                    } else {
                        // Entire document is new
                        entries.append(ConfigChangeEntry(
                            key: key,
                            oldValue: nil,
                            newValue: currentVal,
                            changeKind: .added,
                            category: category,
                            lineNumber: lineNumber
                        ))
                        addedCount += 1
                    }
                }

            case .comment:
                preservedUnmanagedCount += 1

            case .blank:
                break

            case .unrecognized:
                preservedUnmanagedCount += 1
            }
        }

        // 2. Identify keys that existed in original document but were deleted in current document
        if let original = original {
            for line in original.lines {
                if case .assignment(let a) = line {
                    let key = a.key
                    if !processedKeys.contains(key) {
                        processedKeys.insert(key)
                        let origVal: String
                        if key == "font-family" || key == "env" {
                            origVal = original.allValues(for: key).joined(separator: " -> ")
                        } else {
                            origVal = original.effectiveValue(for: key) ?? a.value
                        }

                        let isManaged = GhosttyManagedKeys.isManaged(key: key)
                        let category: SettingTypeCategory = isManaged ? .managed : .unmanaged

                        entries.append(ConfigChangeEntry(
                            key: key,
                            oldValue: origVal,
                            newValue: nil,
                            changeKind: .removed,
                            category: category,
                            lineNumber: nil
                        ))
                        removedCount += 1
                    }
                }
            }
        }

        return GhosttyConfigDiff(
            allEntries: entries,
            addedCount: addedCount,
            modifiedCount: modifiedCount,
            removedCount: removedCount,
            untouchedManagedCount: untouchedManagedCount,
            preservedUnmanagedCount: preservedUnmanagedCount
        )
    }

    /// Reverts an individual change entry back to its baseline value on the ViewModel.
    @MainActor
    public static func revert(entry: ConfigChangeEntry, on viewModel: AppViewModel) {
        switch entry.changeKind {
        case .added:
            viewModel.removeSetting(key: entry.key)

        case .modified, .removed:
            if let original = viewModel.originalDocument {
                let origIndices = original.lines.indices.filter { original.lines[$0].assignment?.key == entry.key }
                if !origIndices.isEmpty {
                    viewModel.updateDocument { doc in
                        // Remove any current lines with this key
                        let currentIndices = doc.lines.indices.filter { doc.lines[$0].assignment?.key == entry.key }
                        let targetIndex: Int
                        if let firstCur = currentIndices.first {
                            targetIndex = firstCur
                            for idx in currentIndices.reversed() {
                                doc.lines.remove(at: idx)
                            }
                        } else {
                            targetIndex = min(origIndices[0], doc.lines.count)
                        }

                        // Re-insert the original lines with original formatting
                        for (offset, origIdx) in origIndices.enumerated() {
                            let origLine = original.lines[origIdx]
                            let insertAt = min(targetIndex + offset, doc.lines.count)
                            doc.lines.insert(origLine, at: insertAt)
                        }
                    }
                    return
                }
            }

            if let old = entry.oldValue {
                viewModel.updateSetting(key: entry.key, value: old)
            } else {
                viewModel.removeSetting(key: entry.key)
            }

        case .untouched:
            break
        }
    }
}
