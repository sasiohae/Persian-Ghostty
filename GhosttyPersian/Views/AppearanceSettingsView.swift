import SwiftUI

/// View managing Ghostty theme selection, background opacity, blur effects, cursor style, and appearance overrides.
public struct AppearanceSettingsView: View {
    @Environment(AppViewModel.self) private var environmentViewModel: AppViewModel?
    @State private var fallbackViewModel = AppViewModel()

    private var viewModel: AppViewModel {
        environmentViewModel ?? fallbackViewModel
    }

    @State private var themeSearchText: String = ""
    @State private var selectedColorSchemeFilter: GhosttyThemeColorScheme = .all
    @State private var showCustomThemeSheet: Bool = false
    @State private var customThemeInput: String = ""

    public init() {}

    public var body: some View {
        Form {
            // MARK: - Save Banner
            if viewModel.isDirty {
                Section {
                    changeStatusBar
                }
            }

            // MARK: - Theme Selection
            Section {
                themeFilterBar
                themePickerRow
            } header: {
                Label("Ghostty Theme", systemImage: "paintpalette")
            } footer: {
                Text("Select from Ghostty's built-in themes. Themes configure the 16 ANSI colors, background, and foreground.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - Transparency & Blur
            Section {
                opacityRow
                blurStyleRow
            } header: {
                Label("Transparency & Blur", systemImage: "macwindow")
            } footer: {
                Text("Translucent backgrounds allow wallpaper and background windows to show through. On macOS, opacity applies when not in fullscreen mode.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - Cursor Customization
            Section {
                cursorStyleRow
                cursorBlinkRow
                cursorColorRow
            } header: {
                Label("Cursor Customization", systemImage: "cursorarrow.ibeam")
            }

            // MARK: - Color Overrides
            Section {
                backgroundColorRow
                foregroundColorRow
            } header: {
                Label("Color Overrides", systemImage: "slider.horizontal.3")
            } footer: {
                Text("Leave blank to inherit colors from the active theme. Overrides take precedence over theme defaults.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - Live Appearance Preview
            Section {
                previewSection
            } header: {
                Label("Live Terminal Preview", systemImage: "eye")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Appearance")
    }

    // MARK: - Component Rows

    private var themeFilterBar: some View {
        HStack(spacing: 12) {
            TextField("Search themes...", text: $themeSearchText)
                .textFieldStyle(.roundedBorder)

            Picker("Filter", selection: $selectedColorSchemeFilter) {
                Text("All").tag(GhosttyThemeColorScheme.all)
                Text("Dark").tag(GhosttyThemeColorScheme.dark)
                Text("Light").tag(GhosttyThemeColorScheme.light)
            }
            .pickerStyle(.segmented)
            .frame(width: 170)
        }
        .padding(.vertical, 2)
    }

    private var themePickerRow: some View {
        HStack {
            Text("Active Theme")
            Spacer()

            Picker("", selection: Binding(
                get: { viewModel.theme },
                set: { viewModel.theme = $0 }
            )) {
                Text("Ghostty Default (None)").tag("")
                if !viewModel.theme.isEmpty && !filteredThemes.contains(where: { $0.name == viewModel.theme }) {
                    Text(viewModel.theme).tag(viewModel.theme)
                }
                ForEach(filteredThemes) { item in
                    HStack {
                        Text(item.name)
                        if let origin = item.origin {
                            Text("(\(origin))")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tag(item.name)
                }
            }
            .labelsHidden()
            .frame(minWidth: 220, maxWidth: 280)

            Button("Custom...") {
                customThemeInput = viewModel.theme
                showCustomThemeSheet = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .sheet(isPresented: $showCustomThemeSheet) {
                customThemeSheetView
            }
        }
    }

    private var opacityRow: some View {
        HStack(spacing: 16) {
            Text("Background Opacity")
            Slider(
                value: Binding(
                    get: { viewModel.backgroundOpacity },
                    set: { viewModel.backgroundOpacity = $0 }
                ),
                in: 0.1...1.0,
                step: 0.05
            )

            Text("\(Int(round(viewModel.backgroundOpacity * 100)))%")
                .font(.callout.monospacedDigit().weight(.medium))
                .frame(width: 48, alignment: .trailing)
        }
    }

    private var blurStyleRow: some View {
        HStack {
            Text("Background Blur")
            Spacer()
            Picker("", selection: Binding(
                get: { viewModel.blurStyle },
                set: { viewModel.blurStyle = $0 }
            )) {
                ForEach(GhosttyBlurStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .labelsHidden()
            .frame(minWidth: 180)
        }
    }

    private var cursorStyleRow: some View {
        HStack {
            Text("Cursor Style")
            Spacer()
            Picker("", selection: Binding(
                get: { viewModel.cursorStyle },
                set: { viewModel.cursorStyle = $0 }
            )) {
                ForEach(GhosttyCursorStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            .labelsHidden()
            .frame(minWidth: 180)
        }
    }

    private var cursorBlinkRow: some View {
        HStack {
            Text("Cursor Blinking")
            Spacer()
            Picker("", selection: Binding(
                get: {
                    if let blink = viewModel.cursorBlink {
                        return blink ? "true" : "false"
                    }
                    return "default"
                },
                set: { val in
                    if val == "true" { viewModel.cursorBlink = true }
                    else if val == "false" { viewModel.cursorBlink = false }
                    else { viewModel.cursorBlink = nil }
                }
            )) {
                Text("Default (App / Shell)").tag("default")
                Text("Always Blink").tag("true")
                Text("Steady (No Blink)").tag("false")
            }
            .labelsHidden()
            .frame(minWidth: 180)
        }
    }

    private var cursorColorRow: some View {
        HStack {
            Text("Cursor Color")
            Spacer()
            TextField("Default (e.g. #ffffff)", text: Binding(
                get: { viewModel.cursorColor },
                set: { viewModel.cursorColor = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 180)
            .font(.system(.body, design: .monospaced))
        }
    }

    private var backgroundColorRow: some View {
        HStack {
            Text("Background Color")
            Spacer()
            TextField("Theme Default (e.g. #1e1e2e)", text: Binding(
                get: { viewModel.customBackground },
                set: { viewModel.customBackground = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 180)
            .font(.system(.body, design: .monospaced))
        }
    }

    private var foregroundColorRow: some View {
        HStack {
            Text("Foreground Color")
            Spacer()
            TextField("Theme Default (e.g. #cdd6f4)", text: Binding(
                get: { viewModel.customForeground },
                set: { viewModel.customForeground = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 180)
            .font(.system(.body, design: .monospaced))
        }
    }

    private var previewSection: some View {
        VStack(spacing: 0) {
            // Simulated macOS Window Titlebar
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle().fill(Color.red).frame(width: 10, height: 10)
                    Circle().fill(Color.yellow).frame(width: 10, height: 10)
                    Circle().fill(Color.green).frame(width: 10, height: 10)
                }
                Spacer()
                Text("Ghostty — \(viewModel.theme.isEmpty ? "Default Theme" : viewModel.theme)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Color.clear.frame(width: 40, height: 10)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.85))

            Divider()

            // Terminal Body Mockup
            VStack(alignment: .leading, spacing: 6) {
                Text("mac@GhosttyPersian ~ % ghostty --version")
                    .foregroundStyle(.secondary)
                Text(viewModel.cliStatus.version?.components(separatedBy: .newlines).first ?? "Ghostty 1.3.1 (Metal)")
                    .foregroundStyle(.primary)

                Text("mac@GhosttyPersian ~ % echo \"سلام دنیا! Persian Ghostty\"")
                    .foregroundStyle(.secondary)
                HStack(spacing: 0) {
                    Text("سلام دنیا! Persian Ghostty ")
                        .foregroundStyle(.primary)
                    cursorGraphic
                }

                HStack(spacing: 8) {
                    Text("[Theme: \(viewModel.theme.isEmpty ? "Default" : viewModel.theme)]")
                        .font(.caption2.monospaced())
                        .foregroundStyle(Color.accentColor)
                    Text("[Opacity: \(Int(round(viewModel.backgroundOpacity * 100)))%]")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                    if viewModel.blurStyle != .disabled {
                        Text("[\(viewModel.blurStyle.displayName)]")
                            .font(.caption2.monospaced())
                            .foregroundStyle(.green)
                    }
                }
                .padding(.top, 4)
            }
            .font(.custom(viewModel.primaryFontFamily, size: CGFloat(min(viewModel.fontSize, 14)), relativeTo: .body))
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(simulatedTerminalBackground)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .padding(.vertical, 4)
    }

    private var simulatedTerminalBackground: some View {
        ZStack {
            if let customHex = Color(hex: viewModel.customBackground) {
                customHex.opacity(viewModel.backgroundOpacity)
            } else {
                Color(nsColor: .textBackgroundColor).opacity(viewModel.backgroundOpacity)
            }
        }
    }

    @ViewBuilder
    private var cursorGraphic: some View {
        let cursorCol = Color(hex: viewModel.cursorColor) ?? Color.accentColor
        switch viewModel.cursorStyle {
        case .block:
            Rectangle()
                .fill(cursorCol)
                .frame(width: 8, height: 16)
        case .bar:
            Rectangle()
                .fill(cursorCol)
                .frame(width: 2, height: 16)
        case .underline:
            VStack {
                Spacer()
                Rectangle()
                    .fill(cursorCol)
                    .frame(width: 8, height: 2)
            }
            .frame(width: 8, height: 16)
        case .blockHollow:
            Rectangle()
                .stroke(cursorCol, lineWidth: 1.5)
                .frame(width: 8, height: 16)
        }
    }

    private var customThemeSheetView: some View {
        VStack(spacing: 16) {
            Text("Enter Custom Theme Name")
                .font(.headline)

            TextField("e.g. 3024 Night, Tokyo Night, Dracula", text: $customThemeInput)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)

            HStack(spacing: 12) {
                Button("Cancel") {
                    showCustomThemeSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Set Theme") {
                    viewModel.theme = customThemeInput.trimmingCharacters(in: .whitespaces)
                    showCustomThemeSheet = false
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 320)
    }

    private var changeStatusBar: some View {
        HStack {
            Image(systemName: "pencil.circle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Unsaved Changes")
                    .font(.headline)
                Text("Appearance customizations are held in memory.")
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

    // MARK: - Helpers

    private var filteredThemes: [GhosttyTheme] {
        let all = viewModel.themesState.themes
        var list = all

        if !themeSearchText.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(themeSearchText) }
        }

        return list
    }
}

// MARK: - Color Hex Initializer

extension Color {
    init?(hex: String) {
        var cleanHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanHex.hasPrefix("#") {
            cleanHex.removeFirst()
        }
        guard cleanHex.count == 6, let rgbValue = UInt64(cleanHex, radix: 16) else {
            return nil
        }
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
