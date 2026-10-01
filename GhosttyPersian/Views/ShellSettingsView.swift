import SwiftUI
import AppKit

/// View managing Ghostty shell commands, shell integration, working directory, and terminal environment.
public struct ShellSettingsView: View {
    @Environment(AppViewModel.self) private var environmentViewModel: AppViewModel?
    @State private var fallbackViewModel = AppViewModel()

    private var viewModel: AppViewModel {
        environmentViewModel ?? fallbackViewModel
    }

    @State private var newEnvKey: String = ""
    @State private var newEnvValue: String = ""
    @State private var showAdvancedFeatures: Bool = false

    public init() {}

    public var body: some View {
        Form {
            // MARK: - Save Banner
            if viewModel.isDirty {
                Section {
                    changeStatusBar
                }
            }

            // MARK: - Shell Command
            Section {
                commandPresetRow
                commandTextFieldRow
            } header: {
                Label("Shell Command & Executable", systemImage: "terminal")
            } footer: {
                Text("Leave empty to use the system default shell ($SHELL). Custom commands are offloaded to Ghostty.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - Shell Integration
            Section {
                shellIntegrationModeRow

                if viewModel.shellIntegration != .none {
                    DisclosureGroup(
                        isExpanded: $showAdvancedFeatures,
                        content: {
                            ForEach(GhosttyShellFeature.allCases) { feature in
                                Toggle(isOn: Binding(
                                    get: { viewModel.isShellFeatureEnabled(feature) },
                                    set: { viewModel.setShellFeature(feature, enabled: $0) }
                                )) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(feature.displayName)
                                        Text(feature.featureDescription)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        },
                        label: {
                            HStack {
                                Text("Integration Features")
                                    .font(.subheadline)
                                Spacer()
                                Text(featuresSummaryText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    )
                }
            } header: {
                Label("Shell Integration", systemImage: "sparkles")
            } footer: {
                Text("Enables prompt jumping, directory tracking across tabs, terminal title reporting, and cursor management.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - Working Directory
            Section {
                workingDirectoryModeRow

                if viewModel.workingDirectoryMode == .custom {
                    customDirectoryRow
                }

                Toggle("Inherit Directory in New Windows", isOn: Binding(
                    get: { viewModel.windowInheritWorkingDirectory },
                    set: { viewModel.windowInheritWorkingDirectory = $0 }
                ))

                Toggle("Inherit Directory in New Tabs", isOn: Binding(
                    get: { viewModel.tabInheritWorkingDirectory },
                    set: { viewModel.tabInheritWorkingDirectory = $0 }
                ))
            } header: {
                Label("Working Directory", systemImage: "folder")
            } footer: {
                Text("Controls the starting directory for new terminal surfaces, windows, and tabs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - Terminal Type & Environment
            Section {
                terminalTypeRow

                if !viewModel.environmentVariables.isEmpty {
                    ForEach(viewModel.environmentVariables) { envVar in
                        HStack {
                            Text(envVar.key)
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                            Text("=")
                                .foregroundStyle(.secondary)
                            Text(envVar.value)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button(role: .destructive) {
                                viewModel.removeEnvironmentVariable(key: envVar.key)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }

                addEnvironmentVariableRow
            } header: {
                Label("Terminal Type & Environment", systemImage: "slider.horizontal.3")
            } footer: {
                Text("Configure the TERM identifier and extra environment variables passed via `env = KEY=VALUE`.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Shell")
    }

    // MARK: - Component Rows

    private var commandPresetRow: some View {
        HStack {
            Text("Shell Preset")
            Spacer()
            Picker("", selection: Binding(
                get: {
                    let cmd = viewModel.shellCommand.trimmingCharacters(in: .whitespaces)
                    if cmd.isEmpty { return "default" }
                    if cmd == "/bin/zsh" { return "zsh" }
                    if cmd == "/bin/bash" { return "bash" }
                    if cmd == "/opt/homebrew/bin/fish" { return "fish" }
                    return "custom"
                },
                set: { preset in
                    switch preset {
                    case "default":
                        viewModel.shellCommand = ""
                    case "zsh":
                        viewModel.shellCommand = "/bin/zsh"
                    case "bash":
                        viewModel.shellCommand = "/bin/bash"
                    case "fish":
                        viewModel.shellCommand = "/opt/homebrew/bin/fish"
                    default:
                        break
                    }
                }
            )) {
                Text("Default ($SHELL)").tag("default")
                Text("Zsh (/bin/zsh)").tag("zsh")
                Text("Bash (/bin/bash)").tag("bash")
                Text("Fish (/opt/homebrew/bin/fish)").tag("fish")
                Text("Custom...").tag("custom")
            }
            .labelsHidden()
            .frame(minWidth: 200)
        }
    }

    private var commandTextFieldRow: some View {
        HStack(spacing: 8) {
            Text("Command / Binary")
            TextField("e.g. /bin/zsh or tmux", text: Binding(
                get: { viewModel.shellCommand },
                set: { viewModel.shellCommand = $0 }
            ))
            .textFieldStyle(.roundedBorder)

            if !viewModel.shellCommand.isEmpty {
                Button {
                    viewModel.shellCommand = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var shellIntegrationModeRow: some View {
        HStack {
            Text("Integration Mode")
            Spacer()
            Picker("", selection: Binding(
                get: { viewModel.shellIntegration },
                set: { viewModel.shellIntegration = $0 }
            )) {
                ForEach(GhosttyShellIntegrationMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .labelsHidden()
            .frame(minWidth: 200)
        }
    }

    private var featuresSummaryText: String {
        let activeCount = GhosttyShellFeature.allCases.filter { viewModel.isShellFeatureEnabled($0) }.count
        return "\(activeCount) of \(GhosttyShellFeature.allCases.count) enabled"
    }

    private var workingDirectoryModeRow: some View {
        HStack {
            Text("Working Directory")
            Spacer()
            Picker("", selection: Binding(
                get: { viewModel.workingDirectoryMode },
                set: { viewModel.workingDirectoryMode = $0 }
            )) {
                ForEach(GhosttyWorkingDirectoryMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .labelsHidden()
            .frame(minWidth: 220)
        }
    }

    private var customDirectoryRow: some View {
        HStack(spacing: 8) {
            TextField("Directory Path (e.g. ~/Projects)", text: Binding(
                get: { viewModel.customWorkingDirectoryPath },
                set: { viewModel.customWorkingDirectoryPath = $0 }
            ))
            .textFieldStyle(.roundedBorder)

            Button {
                selectFolder()
            } label: {
                Label("Browse...", systemImage: "folder")
            }
        }
    }

    @MainActor
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.prompt = "Select Directory"
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.customWorkingDirectoryPath = url.path
        }
    }

    private var terminalTypeRow: some View {
        HStack {
            Text("Terminal Identifier (TERM)")
            Spacer()
            Picker("", selection: Binding(
                get: {
                    let term = viewModel.terminalType
                    if term == "xterm-ghostty" || term == "xterm-256color" || term == "xterm" {
                        return term
                    }
                    return "custom"
                },
                set: { val in
                    if val != "custom" {
                        viewModel.terminalType = val
                    }
                }
            )) {
                Text("xterm-ghostty (Default)").tag("xterm-ghostty")
                Text("xterm-256color").tag("xterm-256color")
                Text("xterm").tag("xterm")
                Text("Custom...").tag("custom")
            }
            .labelsHidden()
            .frame(minWidth: 180)
        }
    }

    private var addEnvironmentVariableRow: some View {
        HStack(spacing: 8) {
            TextField("Variable (e.g. COLORTERM)", text: $newEnvKey)
                .textFieldStyle(.roundedBorder)
                .frame(width: 160)

            Text("=")
                .foregroundStyle(.secondary)

            TextField("Value (e.g. truecolor)", text: $newEnvValue)
                .textFieldStyle(.roundedBorder)

            Button {
                viewModel.addEnvironmentVariable(key: newEnvKey, value: newEnvValue)
                newEnvKey = ""
                newEnvValue = ""
            } label: {
                Label("Add", systemImage: "plus")
            }
            .disabled(newEnvKey.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var changeStatusBar: some View {
        HStack {
            Image(systemName: "pencil.circle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Unsaved Changes")
                    .font(.headline)
                Text("Shell configurations are held in memory.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Revert") {
                viewModel.resetChanges()
            }
            .buttonStyle(.bordered)

            Button("Save Configuration") {
                Task {
                    _ = await viewModel.saveConfiguration()
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 4)
    }
}
