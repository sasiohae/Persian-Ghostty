import SwiftUI

/// View managing General Ghostty environment status, active configuration file discovery, health validation, and persistence.
public struct GeneralSettingsView: View {
    @Environment(AppViewModel.self) private var environmentViewModel: AppViewModel?
    @State private var fallbackViewModel = AppViewModel()

    private var viewModel: AppViewModel {
        environmentViewModel ?? fallbackViewModel
    }

    @State private var showCandidates: Bool = false
    @State private var isSaving: Bool = false
    @State private var isValidating: Bool = false

    public init() {}

    public var body: some View {
        Form {
            // MARK: - Save / Revert Banner (when dirty or recent save)
            if viewModel.isDirty || isSaveActive {
                Section {
                    changeStatusBar
                }
            }

            // MARK: - Ghostty Executable Status
            Section {
                executableStatusRow
                if let version = viewModel.cliStatus.version {
                    LabeledContent("Version") {
                        Text(version.components(separatedBy: .newlines).first ?? version)
                            .font(.callout)
                    }
                }
                if let path = viewModel.cliStatus.executableURL?.path {
                    LabeledContent("Binary Location") {
                        Text(path)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            } header: {
                Label("Ghostty Terminal", systemImage: "terminal")
            } footer: {
                HStack(spacing: 12) {
                    Button {
                        viewModel.openGhosttyBinaryInFinder()
                    } label: {
                        Label("Reveal Binary in Finder", systemImage: "folder")
                    }
                    .disabled(!viewModel.cliStatus.isAvailable)

                    Button {
                        Task {
                            await viewModel.checkCLIStatus()
                        }
                    } label: {
                        Label("Check Again", systemImage: "arrow.clockwise")
                    }
                }
                .padding(.top, 4)
            }

            // MARK: - Active Configuration Location
            Section {
                effectiveConfigPathRow
                precedenceScopeRow
                candidatesDisclosureRow
            } header: {
                Label("Configuration File", systemImage: "doc.text")
            } footer: {
                HStack(spacing: 12) {
                    Button {
                        viewModel.openConfigurationInEditor()
                    } label: {
                        Label("Open in Editor", systemImage: "square.and.pencil")
                    }
                    .disabled(viewModel.effectivePath?.exists != true)

                    Button {
                        viewModel.openConfigurationInFinder()
                    } label: {
                        Label("Reveal in Finder", systemImage: "folder")
                    }
                    .disabled(viewModel.effectivePath == nil)

                    Button {
                        Task {
                            await viewModel.reloadConfiguration()
                        }
                    } label: {
                        Label("Reload from Disk", systemImage: "arrow.clockwise")
                    }
                }
                .padding(.top, 4)
            }

            // MARK: - Validation & Diagnostics
            Section {
                validationStatusRow
                if case .invalid(let issues, _) = viewModel.validationState, !issues.isEmpty {
                    validationIssuesList(issues)
                }
            } header: {
                Label("Configuration Health", systemImage: "checkmark.shield")
            } footer: {
                HStack(spacing: 12) {
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
                            Label("Validate with Ghostty", systemImage: "checkmark.shield")
                        }
                    }
                    .disabled(!viewModel.cliStatus.isAvailable || isValidating)

                    if !viewModel.cliStatus.isAvailable {
                        Text("Validation requires Ghostty to be installed.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("General")
    }

    // MARK: - Subviews & Rows

    private var changeStatusBar: some View {
        HStack {
            if viewModel.isDirty {
                Image(systemName: "pencil.circle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unsaved Changes")
                        .font(.headline)
                    Text("Your working configuration has in-memory modifications.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if case .saved = viewModel.saveState {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Configuration Saved")
                        .font(.headline)
                    Text("All changes were validated and saved atomically with backup.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if case .failed(let error) = viewModel.saveState {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Save Failed")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if viewModel.isDirty {
                Button("Revert") {
                    viewModel.resetChanges()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                Button {
                    Task {
                        isSaving = true
                        _ = await viewModel.saveConfiguration()
                        isSaving = false
                    }
                } label: {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Save Configuration")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(isSaving)
            }
        }
        .padding(.vertical, 4)
    }

    private var executableStatusRow: some View {
        LabeledContent("Status") {
            if viewModel.cliStatus.isAvailable {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Installed & Ready")
                        .font(.callout.weight(.medium))
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Not Found")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var effectiveConfigPathRow: some View {
        LabeledContent("Active Path") {
            if let path = viewModel.effectivePath {
                HStack(spacing: 8) {
                    Text(path.url.path)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)

                    if path.exists {
                        Text("Active")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    } else {
                        Text("Not Created")
                            .font(.caption2.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                    }
                }
            } else {
                Text("Searching for configuration...")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var precedenceScopeRow: some View {
        LabeledContent("Precedence") {
            if let path = viewModel.effectivePath {
                HStack(spacing: 6) {
                    Text(path.scope.rawValue)
                        .font(.callout.weight(.medium))
                    Text("(Rank #\(path.precedenceOrder) of 4)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("N/A")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var candidatesDisclosureRow: some View {
        DisclosureGroup(
            isExpanded: $showCandidates,
            content: {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(viewModel.candidatePaths) { candidate in
                        HStack(alignment: .center, spacing: 8) {
                            Image(systemName: candidate.exists ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(candidate.exists ? .green : .secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(candidate.url.lastPathComponent)
                                        .font(.caption.monospaced().weight(.semibold))
                                    Text("[\(candidate.scope.rawValue) - Rank #\(candidate.precedenceOrder)]")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)

                                    if candidate.url == viewModel.effectivePath?.url && candidate.exists {
                                        Text("EFFECTIVE")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.accentColor.opacity(0.15))
                                            .foregroundStyle(Color.accentColor)
                                            .clipShape(RoundedRectangle(cornerRadius: 3))
                                    }
                                }
                                Text(candidate.url.path)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
                .padding(.vertical, 6)
            },
            label: {
                Text("Show All Candidate Locations")
                    .font(.callout)
            }
        )
    }

    private var validationStatusRow: some View {
        LabeledContent("Validation Status") {
            switch viewModel.validationState {
            case .valid:
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Configuration is valid")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.green)
                }
            case .invalid(let issues, _):
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text("\(issues.count) issue(s) detected")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.red)
                }
            case .validating:
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Validating with Ghostty...")
                        .font(.callout)
                }
            case .skipped(let reason):
                Text("Skipped (\(reason))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            case .unknown:
                Text("Not validated")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func validationIssuesList(_ issues: [GhosttyValidationIssue]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(issues) { issue in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.red)
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 2) {
                        if let key = issue.key {
                            Text(key)
                                .font(.caption.monospaced().weight(.semibold))
                        }
                        Text(issue.message)
                            .font(.caption)
                            .foregroundStyle(.primary)
                        if let line = issue.line {
                            Text("Line \(line)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.vertical, 4)
    }

    private var isSaveActive: Bool {
        if case .saved = viewModel.saveState { return true }
        if case .failed = viewModel.saveState { return true }
        return false
    }
}
