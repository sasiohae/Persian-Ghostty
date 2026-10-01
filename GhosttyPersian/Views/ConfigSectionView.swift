import SwiftUI
import AppKit

/// View managing configuration overview, non-destructive breakdown, live validation, raw preview, and backup history.
public struct ConfigSectionView: View {
    @Environment(AppViewModel.self) private var environmentViewModel: AppViewModel?
    @State private var fallbackViewModel = AppViewModel()

    private var viewModel: AppViewModel {
        environmentViewModel ?? fallbackViewModel
    }

    public enum ConfigTab: String, CaseIterable, Identifiable {
        case overview = "Overview & Health"
        case preview = "Raw Preview"
        case backups = "Backups & History"

        public var id: String { rawValue }

        public var iconName: String {
            switch self {
            case .overview: return "gauge.with.needle"
            case .preview: return "doc.plaintext"
            case .backups: return "clock.arrow.circlepath"
            }
        }
    }

    @State private var selectedTab: ConfigTab = .overview
    @State private var selectedBackupToRestore: GhosttyBackupInfo? = nil
    @State private var showRestoreConfirmation: Bool = false
    @State private var selectedBackupToDelete: GhosttyBackupInfo? = nil
    @State private var showDeleteConfirmation: Bool = false
    @State private var showPruneConfirmation: Bool = false
    @State private var showPendingChangesSheet: Bool = false
    @State private var showDiagnosticSheet: Bool = false
    @State private var copiedToClipboard: Bool = false
    @State private var isSaving: Bool = false
    @State private var isValidating: Bool = false
    @State private var backupStatusMessage: String? = nil

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Navigation Segmented Control
            Picker("", selection: $selectedTab) {
                ForEach(ConfigTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.iconName).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            // MARK: - Selected Tab Content
            switch selectedTab {
            case .overview:
                overviewTab
            case .preview:
                previewTab
            case .backups:
                backupsTab
            }
        }
        .navigationTitle("Configuration")
        .task {
            viewModel.loadBackups()
        }
        .confirmationDialog(
            "Restore Configuration Backup",
            isPresented: $showRestoreConfirmation,
            presenting: selectedBackupToRestore
        ) { backup in
            Button("Restore Backup", role: .destructive) {
                Task {
                    await viewModel.restoreBackup(backup)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { backup in
            Text("Restoring '\(backup.fileName)' will replace your current active configuration. An automatic pre-restoration safety snapshot will be created before applying.")
        }
        .confirmationDialog(
            "Delete Configuration Backup",
            isPresented: $showDeleteConfirmation,
            presenting: selectedBackupToDelete
        ) { backup in
            Button("Delete Backup", role: .destructive) {
                viewModel.deleteBackup(backup)
            }
            Button("Cancel", role: .cancel) {}
        } message: { backup in
            Text("Are you sure you want to permanently delete '\(backup.fileName)'? This action cannot be undone.")
        }
        .confirmationDialog(
            "Prune Older Backups",
            isPresented: $showPruneConfirmation
        ) {
            Button("Prune (Keep 10 Most Recent)", role: .destructive) {
                let pruned = viewModel.pruneBackups(keepLatest: 10)
                backupStatusMessage = "Pruned \(pruned) old backup snapshot(s)."
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all but the 10 most recent configuration backups to conserve disk space.")
        }
        .sheet(isPresented: $showPendingChangesSheet) {
            PendingChangesSheetView(isPresented: $showPendingChangesSheet)
        }
        .sheet(isPresented: $showDiagnosticSheet) {
            if let report = viewModel.activeDiagnostic {
                DiagnosticSheetView(report: report, isPresented: $showDiagnosticSheet)
            }
        }
    }

    // MARK: - Tab 1: Overview & Health

    private var overviewTab: some View {
        Form {
            // Save Banner
            if viewModel.isDirty {
                Section {
                    changeStatusBar
                }
            }

            // File Status & Path
            Section {
                LabeledContent("Configuration File") {
                    Text(viewModel.effectivePath?.url.path ?? "Default macOS Config")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }

                LabeledContent("Disk Status") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.configExists ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(viewModel.configExists ? "Exists on Disk" : "New File (Not Saved Yet)")
                            .font(.callout)
                    }
                }

                if let scope = viewModel.effectivePath?.scope {
                    LabeledContent("Precedence Scope") {
                        Text(scope == .macOS ? "macOS System Domain (~/Library/Application Support/ghostty)" : "XDG Domain (~/.config/ghostty)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Label("Configuration Location", systemImage: "folder")
            } footer: {
                HStack(spacing: 12) {
                    Button {
                        viewModel.openConfigurationInFinder()
                    } label: {
                        Label("Reveal in Finder", systemImage: "folder")
                    }

                    Button {
                        viewModel.openConfigurationInEditor()
                    } label: {
                        Label("Open in Text Editor", systemImage: "arrow.up.forward.app")
                    }
                    .disabled(!viewModel.configExists)
                }
            }

            // Document Breakdown Metrics
            Section {
                breakdownMetricsGrid
            } header: {
                Label("Document Structure & Preservation", systemImage: "chart.bar.doc.horizontal")
            } footer: {
                Text("Ghostty Persian uses a non-destructive line parser: unknown settings and custom comments are preserved 100% intact.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Live Validation
            Section {
                validationStatusRow
            } header: {
                Label("Ghostty CLI Validation", systemImage: "checkmark.shield")
            } footer: {
                HStack {
                    Button {
                        Task {
                            isValidating = true
                            await viewModel.validateCurrentDocument()
                            isValidating = false
                        }
                    } label: {
                        if isValidating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Run Validation Now", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(!viewModel.cliStatus.isAvailable || isValidating)

                    if !viewModel.cliStatus.isAvailable {
                        Text("Ghostty CLI not installed. Validation skipped.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Managed Settings Breakdown
            let breakdown = viewModel.configBreakdown
            if !breakdown.managedItems.isEmpty {
                Section {
                    ForEach(breakdown.managedItems) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(item.key)
                                        .font(.system(.body, design: .monospaced))
                                        .fontWeight(.medium)

                                    if item.isModified {
                                        Text("Modified")
                                            .font(.caption2.weight(.bold))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.2))
                                            .foregroundStyle(.orange)
                                            .clipShape(Capsule())
                                    }

                                    Text(item.category.rawValue)
                                        .font(.caption2)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 1)
                                        .background(Color.secondary.opacity(0.15))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .foregroundStyle(.secondary)
                                }

                                Text(item.value)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if item.isModified {
                                Button("Revert") {
                                    viewModel.revertSetting(key: item.key)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }

                            Button(role: .destructive) {
                                viewModel.removeManagedSetting(key: item.key)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Label("Managed Settings (\(breakdown.managedCount))", systemImage: "slider.horizontal.2.square")
                }
            }

            // Unmanaged User Settings
            if !breakdown.unmanagedItems.isEmpty {
                Section {
                    ForEach(breakdown.unmanagedItems) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.key)
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.medium)
                                Text(item.value)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("Line \(item.lineNumber)")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Text("Protected")
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                    }
                } header: {
                    Label("Custom & Unmanaged Settings (\(breakdown.unmanagedCount))", systemImage: "lock.shield")
                }
            }
        }
        .formStyle(.grouped)
    }

    private var breakdownMetricsGrid: some View {
        let b = viewModel.configBreakdown
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            metricTile(title: "Total Lines", count: "\(b.totalLines)", icon: "doc.text", color: .blue)
            metricTile(title: "Managed Keys", count: "\(b.managedCount)", icon: "slider.horizontal.3", color: .purple)
            metricTile(title: "Protected Custom", count: "\(b.unmanagedCount)", icon: "shield.lefthalf.filled", color: .green)
            metricTile(title: "Comments", count: "\(b.commentLineCount)", icon: "bubble.left", color: .teal)
            metricTile(title: "Blank Lines", count: "\(b.blankLineCount)", icon: "space", color: .gray)
            metricTile(title: "Unsaved Edits", count: "\(b.modifiedCount)", icon: "pencil", color: b.modifiedCount > 0 ? .orange : .secondary)
        }
        .padding(.vertical, 4)
    }

    private func metricTile(title: String, count: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(count)
                .font(.title2.monospacedDigit().weight(.bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var validationStatusRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch viewModel.validationState {
            case .valid:
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Configuration Valid")
                            .font(.headline)
                        Text("Ghostty CLI successfully validated all lines.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            case .invalid(let issues, let raw):
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.title3)
                        Text("\(issues.count) Validation Issue(s)")
                            .font(.headline)
                            .foregroundStyle(.red)
                    }
                    ForEach(issues) { issue in
                        Text("• Line \(issue.line ?? 0): \(issue.message)")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    if issues.isEmpty && !raw.isEmpty {
                        Text(raw)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                    if viewModel.activeDiagnostic != nil {
                        Button {
                            showDiagnosticSheet = true
                        } label: {
                            Label("Inspect Diagnostics Report...", systemImage: "stethoscope")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .padding(.top, 4)
                    }
                }
            case .validating:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Validating with Ghostty CLI...")
                        .font(.subheadline)
                }
            case .skipped(let reason):
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.orange)
                    Text("Validation Skipped: \(reason)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            case .unknown:
                HStack(spacing: 8) {
                    Image(systemName: "circle.dashed")
                        .foregroundStyle(.secondary)
                    Text("Not validated since last edit.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Tab 2: Raw Document Preview

    private var previewTab: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack(spacing: 12) {
                Text("\(viewModel.previewLines.count) Lines")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(viewModel.currentDocument.serialize(), forType: .string)
                    copiedToClipboard = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copiedToClipboard = false
                    }
                } label: {
                    Label(copiedToClipboard ? "Copied!" : "Copy Configuration", systemImage: copiedToClipboard ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.openConfigurationInFinder()
                } label: {
                    Label("Reveal", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.openConfigurationInEditor()
                } label: {
                    Label("Open in Editor", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.configExists)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Monospaced Document Viewer
            ScrollView([.horizontal, .vertical]) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.previewLines) { line in
                        previewLineRow(line)
                    }
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
    }

    private func previewLineRow(_ line: FormattedPreviewLine) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Line number gutter
            Text("\(line.lineNumber)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.secondary.opacity(0.6))
                .frame(width: 36, alignment: .trailing)

            // Line content
            switch line.lineType {
            case .comment:
                Text(line.content)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Color.secondary)
                    .italic()
            case .blank:
                Text(" ")
                    .font(.system(size: 11, design: .monospaced))
            case .managedAssignment(let key, let val):
                HStack(spacing: 4) {
                    Text(key)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.accentColor)
                    Text("=")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(val)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.primary)

                    if line.isModified {
                        Text("[Modified]")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 4)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
            case .unmanagedAssignment(let key, let val):
                HStack(spacing: 4) {
                    Text(key)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary)
                    Text("=")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(val)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("[Preserved]")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.green)
                }
            case .unrecognized:
                Text(line.content)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
        .background(line.isModified ? Color.orange.opacity(0.08) : Color.clear)
    }

    // MARK: - Tab 3: Backups & History

    private var backupsTab: some View {
        VStack(spacing: 0) {
            // Header Info Bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Configuration Backups (\(viewModel.backups.count))")
                        .font(.headline)
                    Text("Automatic collision-resistant snapshots are preserved before every configuration write.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    let snapshot = viewModel.createManualBackup()
                    if snapshot != nil {
                        backupStatusMessage = "Created manual safety snapshot."
                    }
                } label: {
                    Label("Take Snapshot Now", systemImage: "plus.square.on.square")
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.configExists)

                if viewModel.backups.count > 10 {
                    Button {
                        showPruneConfirmation = true
                    } label: {
                        Label("Prune...", systemImage: "scissors")
                    }
                    .buttonStyle(.bordered)
                }

                Button {
                    viewModel.loadBackups()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            if let msg = backupStatusMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(msg)
                        .font(.caption)
                    Spacer()
                    Button {
                        backupStatusMessage = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1))
                Divider()
            }

            if viewModel.backups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No Backups Recorded")
                        .font(.headline)
                    Text("When you save changes to your Ghostty configuration, pre-write safety backups will appear here.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .controlBackgroundColor))
            } else {
                List(viewModel.backups) { backup in
                    HStack(spacing: 12) {
                        Image(systemName: "doc.badge.clock")
                            .font(.title2)
                            .foregroundStyle(.blue)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(backup.fileName)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)

                            HStack(spacing: 8) {
                                Text(backup.relativeTimeString)
                                    .fontWeight(.medium)
                                Text("•")
                                Text(backup.creationDate, style: .date)
                                Text(backup.creationDate, style: .time)
                                Text("•")
                                Text(ByteCountFormatter.string(fromByteCount: backup.sizeInBytes, countStyle: .file))
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([backup.url])
                        } label: {
                            Label("Reveal", systemImage: "folder")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Restore...") {
                            selectedBackupToRestore = backup
                            showRestoreConfirmation = true
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button(role: .destructive) {
                            selectedBackupToDelete = backup
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var changeStatusBar: some View {
        HStack {
            Image(systemName: "pencil.circle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Unsaved Changes")
                    .font(.headline)
                Text("\(viewModel.configBreakdown.modifiedCount) setting(s) modified in memory.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showPendingChangesSheet = true
            } label: {
                Label("Review Changes...", systemImage: "doc.text.magnifyingglass")
            }
            .buttonStyle(.bordered)

            Button("Revert All") {
                viewModel.resetChanges()
            }
            .buttonStyle(.bordered)

            Button {
                Task {
                    isSaving = true
                    _ = await viewModel.saveConfiguration()
                    isSaving = false
                }
            } label: {
                if isSaving {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Save Configuration")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSaving)
        }
        .padding(.vertical, 4)
    }
}
