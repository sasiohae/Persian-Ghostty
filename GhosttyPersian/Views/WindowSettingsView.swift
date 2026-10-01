import SwiftUI

/// View managing Ghostty macOS titlebar style, window padding, traffic-light controls, and resize behavior.
public struct WindowSettingsView: View {
    @Environment(AppViewModel.self) private var environmentViewModel: AppViewModel?
    @State private var fallbackViewModel = AppViewModel()

    private var viewModel: AppViewModel {
        environmentViewModel ?? fallbackViewModel
    }

    public init() {}

    public var body: some View {
        Form {
            // MARK: - Save Banner
            if viewModel.isDirty {
                Section {
                    changeStatusBar
                }
            }

            // MARK: - Titlebar & Frame Style
            Section {
                titlebarStyleRow
                windowButtonsToggle
                proxyIconToggle
                decorationsToggle
            } header: {
                Label("macOS Titlebar & Frame", systemImage: "macwindow")
            } footer: {
                Text("Changes to titlebar style apply to new terminal windows.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - Inner Window Padding
            Section {
                paddingXRow
                paddingYRow
                paddingBalanceToggle
            } header: {
                Label("Window Padding & Margins", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
            } footer: {
                Text("Inner padding defines the spacing between terminal text cells and the window frame.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - Window Lifecycle & Resizing
            Section {
                saveStatePolicyRow
                stepResizeToggle
                windowThemeRow
                nonNativeFullscreenToggle
            } header: {
                Label("Window Lifecycle & Resizing", systemImage: "arrow.triangle.2.circlepath")
            }

            // MARK: - Live Window Frame Preview
            Section {
                previewSection
            } header: {
                Label("Live Window Mockup", systemImage: "eye")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Window")
    }

    // MARK: - Component Rows

    private var titlebarStyleRow: some View {
        HStack {
            Text("Titlebar Style")
            Spacer()
            Picker("", selection: Binding(
                get: { viewModel.macosTitlebarStyle },
                set: { viewModel.macosTitlebarStyle = $0 }
            )) {
                ForEach(MacOSTitlebarStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .labelsHidden()
            .frame(minWidth: 220)
        }
    }

    private var windowButtonsToggle: some View {
        Toggle("Show Window Buttons (Traffic Lights)", isOn: Binding(
            get: { viewModel.macosWindowButtons },
            set: { viewModel.macosWindowButtons = $0 }
        ))
        .disabled(viewModel.macosTitlebarStyle == .hidden || !viewModel.windowDecorations)
    }

    private var proxyIconToggle: some View {
        Toggle("Show Proxy Directory Icon in Titlebar", isOn: Binding(
            get: { viewModel.macosTitlebarProxyIcon },
            set: { viewModel.macosTitlebarProxyIcon = $0 }
        ))
        .disabled(viewModel.macosTitlebarStyle != .native)
    }

    private var decorationsToggle: some View {
        Toggle("Enable Window Frame Decorations", isOn: Binding(
            get: { viewModel.windowDecorations },
            set: { viewModel.windowDecorations = $0 }
        ))
    }

    private var paddingXRow: some View {
        HStack(spacing: 16) {
            Text("Horizontal Padding")
            Slider(
                value: Binding(
                    get: { Double(viewModel.windowPaddingX) },
                    set: { viewModel.windowPaddingX = Int($0) }
                ),
                in: 0...64,
                step: 1
            )
            HStack(spacing: 4) {
                Text("\(viewModel.windowPaddingX) px")
                    .font(.callout.monospacedDigit().weight(.medium))
                    .frame(width: 50, alignment: .trailing)
                Stepper("", value: Binding(
                    get: { viewModel.windowPaddingX },
                    set: { viewModel.windowPaddingX = $0 }
                ), in: 0...128)
                .labelsHidden()
            }
        }
    }

    private var paddingYRow: some View {
        HStack(spacing: 16) {
            Text("Vertical Padding")
            Slider(
                value: Binding(
                    get: { Double(viewModel.windowPaddingY) },
                    set: { viewModel.windowPaddingY = Int($0) }
                ),
                in: 0...64,
                step: 1
            )
            HStack(spacing: 4) {
                Text("\(viewModel.windowPaddingY) px")
                    .font(.callout.monospacedDigit().weight(.medium))
                    .frame(width: 50, alignment: .trailing)
                Stepper("", value: Binding(
                    get: { viewModel.windowPaddingY },
                    set: { viewModel.windowPaddingY = $0 }
                ), in: 0...128)
                .labelsHidden()
            }
        }
    }

    private var paddingBalanceToggle: some View {
        Toggle("Balance Horizontal Padding Evenly", isOn: Binding(
            get: { viewModel.windowPaddingBalance },
            set: { viewModel.windowPaddingBalance = $0 }
        ))
    }

    private var saveStatePolicyRow: some View {
        HStack {
            Text("Window State Restoration")
            Spacer()
            Picker("", selection: Binding(
                get: { viewModel.windowSaveState },
                set: { viewModel.windowSaveState = $0 }
            )) {
                ForEach(WindowSaveStatePolicy.allCases) { policy in
                    Text(policy.displayName).tag(policy)
                }
            }
            .labelsHidden()
            .frame(minWidth: 200)
        }
    }

    private var stepResizeToggle: some View {
        Toggle("Resize in Discrete Character Cell Steps", isOn: Binding(
            get: { viewModel.windowStepResize },
            set: { viewModel.windowStepResize = $0 }
        ))
    }

    private var windowThemeRow: some View {
        HStack {
            Text("Window Frame Theme")
            Spacer()
            Picker("", selection: Binding(
                get: { viewModel.windowTheme },
                set: { viewModel.windowTheme = $0 }
            )) {
                ForEach(WindowThemeMode.allCases) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
            .labelsHidden()
            .frame(minWidth: 200)
        }
    }

    private var nonNativeFullscreenToggle: some View {
        Toggle("Use Non-Native Fast Fullscreen", isOn: Binding(
            get: { viewModel.macosNonNativeFullscreen },
            set: { viewModel.macosNonNativeFullscreen = $0 }
        ))
    }

    private var previewSection: some View {
        VStack(spacing: 0) {
            // Titlebar Mockup based on selected style
            if viewModel.macosTitlebarStyle != .hidden {
                HStack(spacing: 8) {
                    if viewModel.macosWindowButtons {
                        HStack(spacing: 6) {
                            Circle().fill(Color.red).frame(width: 10, height: 10)
                            Circle().fill(Color.yellow).frame(width: 10, height: 10)
                            Circle().fill(Color.green).frame(width: 10, height: 10)
                        }
                    } else {
                        Color.clear.frame(width: 48, height: 10)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        if viewModel.macosTitlebarProxyIcon && viewModel.macosTitlebarStyle == .native {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        Text("ghostty ~ \(viewModel.primaryFontFamily)")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                    Color.clear.frame(width: 48, height: 10)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(titlebarBackground)

                Divider()
            }

            // Terminal Body with Applied Live Padding
            VStack(alignment: .leading, spacing: 6) {
                Text("Ghostty Terminal Window Container")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.accentColor)

                Text("Padding Applied: X=\(viewModel.windowPaddingX)px, Y=\(viewModel.windowPaddingY)px")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)

                Text("echo \"سلام دنیا! Persian Ghostty\"")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)

                HStack(spacing: 6) {
                    Text("[Style: \(viewModel.macosTitlebarStyle.rawValue)]")
                    Text("[Restore: \(viewModel.windowSaveState.rawValue)]")
                    if viewModel.windowPaddingBalance {
                        Text("[Balanced]")
                            .foregroundStyle(.green)
                    }
                }
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, CGFloat(viewModel.windowPaddingX + 8))
            .padding(.vertical, CGFloat(viewModel.windowPaddingY + 8))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .textBackgroundColor))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .padding(.vertical, 4)
    }

    private var titlebarBackground: some View {
        switch viewModel.macosTitlebarStyle {
        case .transparent:
            return Color(nsColor: .windowBackgroundColor).opacity(0.3)
        case .native:
            return Color(nsColor: .windowBackgroundColor).opacity(0.95)
        case .tabs:
            return Color(nsColor: .controlBackgroundColor).opacity(0.9)
        case .hidden:
            return Color.clear.opacity(0)
        }
    }

    private var changeStatusBar: some View {
        HStack {
            Image(systemName: "pencil.circle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Unsaved Changes")
                    .font(.headline)
                Text("Window layout customizations are held in memory.")
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
