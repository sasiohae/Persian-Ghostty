import SwiftUI

/// Dedicated inspection sheet presenting itemized diffs, modification summaries, and per-key revert actions.
public struct PendingChangesSheetView: View {
    @Environment(AppViewModel.self) private var environmentViewModel: AppViewModel?
    @State private var fallbackViewModel = AppViewModel()

    private var viewModel: AppViewModel {
        environmentViewModel ?? fallbackViewModel
    }

    @Binding var isPresented: Bool
    @State private var showAllEntries: Bool = false
    @State private var isSaving: Bool = false

    public init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    public var body: some View {
        let diff = viewModel.pendingDiff

        VStack(spacing: 0) {
            // MARK: - Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Pending Configuration Changes")
                        .font(.title2.weight(.bold))
                    Text("Review differences between saved disk configuration and in-memory modifications.")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // MARK: - Summary Statistics Bar
            summaryStatsBar(diff: diff)

            Divider()

            // MARK: - Filter Bar
            HStack {
                Text(showAllEntries ? "Showing All Settings & Lines" : "Showing Pending Changes Only")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.secondary)

                Spacer()

                Toggle("Include Untouched & Preserved", isOn: $showAllEntries)
                    .toggleStyle(.checkbox)
                    .font(.caption)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

            Divider()

            // MARK: - Diff Entries List
            let entries = showAllEntries ? diff.allEntries : diff.changedEntries

            if entries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.green)
                    Text("No Pending Changes")
                        .font(.headline)
                    Text("Working configuration matches disk content exactly.")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .controlBackgroundColor))
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(entries) { entry in
                            changeEntryRow(entry)
                            Divider()
                        }
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor))
            }

            Divider()

            // MARK: - Footer Actions
            HStack(spacing: 12) {
                Button("Revert All Changes") {
                    viewModel.resetChanges()
                    if !diff.hasChanges {
                        isPresented = false
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!diff.hasChanges)

                Spacer()

                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)

                Button {
                    Task {
                        isSaving = true
                        let success = await viewModel.saveConfiguration()
                        isSaving = false
                        if success {
                            isPresented = false
                        }
                    }
                } label: {
                    if isSaving {
                        ProgressView().controlSize(.small)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.shield")
                            Text("Commit & Save to Disk")
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!diff.hasChanges || isSaving)
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 680, idealWidth: 740, minHeight: 480, idealHeight: 560)
    }

    // MARK: - Component Views

    private func summaryStatsBar(diff: GhosttyConfigDiff) -> some View {
        HStack(spacing: 16) {
            statBadge(count: diff.modifiedCount, label: "Modified", color: .orange)
            statBadge(count: diff.addedCount, label: "Added", color: .green)
            statBadge(count: diff.removedCount, label: "Removed", color: .red)
            statBadge(count: diff.untouchedManagedCount + diff.preservedUnmanagedCount, label: "Untouched & Protected", color: .teal)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func statBadge(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text("\(count)")
                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func changeEntryRow(_ entry: ConfigChangeEntry) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Status Icon / Badge
            changeKindBadge(entry.changeKind)
                .frame(width: 80, alignment: .leading)

            // Key Name & Line
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.key)
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Color.primary)

                if let line = entry.lineNumber {
                    Text("Line \(line) • \(entry.category.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                } else {
                    Text(entry.category.rawValue)
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                }
            }
            .frame(width: 220, alignment: .leading)

            // Value Differences
            VStack(alignment: .leading, spacing: 3) {
                switch entry.changeKind {
                case .modified:
                    if let old = entry.oldValue {
                        HStack(spacing: 4) {
                            Text("-")
                                .font(.system(.caption, design: .monospaced).weight(.bold))
                                .foregroundStyle(Color.red)
                            Text(old)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Color.secondary)
                                .strikethrough()
                        }
                    }
                    if let new = entry.newValue {
                        HStack(spacing: 4) {
                            Text("+")
                                .font(.system(.caption, design: .monospaced).weight(.bold))
                                .foregroundStyle(Color.green)
                            Text(new)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Color.accentColor)
                        }
                    }

                case .added:
                    if let new = entry.newValue {
                        HStack(spacing: 4) {
                            Text("+")
                                .font(.system(.caption, design: .monospaced).weight(.bold))
                                .foregroundStyle(Color.green)
                            Text(new)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Color.green)
                        }
                    }

                case .removed:
                    if let old = entry.oldValue {
                        HStack(spacing: 4) {
                            Text("-")
                                .font(.system(.caption, design: .monospaced).weight(.bold))
                                .foregroundStyle(Color.red)
                            Text(old)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(Color.red)
                                .strikethrough()
                        }
                    }

                case .untouched:
                    if let val = entry.newValue ?? entry.oldValue {
                        Text(val)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Color.secondary)
                    }
                }
            }

            Spacer()

            // Individual Revert Action
            if entry.isChanged {
                Button("Revert") {
                    viewModel.revertChange(entry)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(rowBackgroundColor(for: entry.changeKind))
    }

    private func changeKindBadge(_ kind: ChangeKind) -> some View {
        HStack(spacing: 4) {
            Image(systemName: kind.iconName)
                .font(.caption2)
            Text(kind.rawValue)
                .font(.caption2.weight(.bold))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .foregroundStyle(colorForKind(kind))
        .background(colorForKind(kind).opacity(0.12))
        .clipShape(Capsule())
    }

    private func colorForKind(_ kind: ChangeKind) -> Color {
        switch kind {
        case .added: return .green
        case .modified: return .orange
        case .removed: return .red
        case .untouched: return .secondary
        }
    }

    private func rowBackgroundColor(for kind: ChangeKind) -> Color {
        switch kind {
        case .added:
            return Color.green.opacity(0.04)
        case .modified:
            return Color.orange.opacity(0.04)
        case .removed:
            return Color.red.opacity(0.04)
        case .untouched:
            return Color.clear
        }
    }
}
