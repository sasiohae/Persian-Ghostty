import SwiftUI

/// View for managing Ghostty font families, fallback fonts, font size, thickening, and cell dimensions.
public struct TypographySettingsView: View {
    @Environment(AppViewModel.self) private var environmentViewModel: AppViewModel?
    @State private var fallbackViewModel = AppViewModel()

    private var viewModel: AppViewModel {
        environmentViewModel ?? fallbackViewModel
    }

    @State private var customFontInput: String = ""
    @State private var showCustomFontSheet: Bool = false
    @State private var selectedNewFallback: String = ""
    @State private var previewMode: PreviewMode = .code

    private enum PreviewMode: String, CaseIterable, Identifiable {
        case code = "Code"
        case symbols = "Symbols"
        case text = "Text"

        var id: String { rawValue }
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

            // MARK: - Primary Font Family
            Section {
                primaryFontRow
            } header: {
                Label("Primary Font Family", systemImage: "textformat")
            } footer: {
                Text("Ghostty's default font for regular text rendering. Changes apply to the primary terminal window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - Font Size
            Section {
                fontSizeRow
            } header: {
                Label("Font Size", systemImage: "textformat.size")
            }

            // MARK: - Fallback Fonts
            Section {
                fallbackFontsList
                addFallbackFontRow
            } header: {
                Label("Fallback Fonts", systemImage: "text.append")
            } footer: {
                Text("Fallback fonts are searched in the order listed whenever a glyph is missing from the primary font.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - Rendering & Features
            Section {
                Toggle("Programming Ligatures", isOn: Binding(
                    get: { viewModel.ligaturesEnabled },
                    set: { viewModel.ligaturesEnabled = $0 }
                ))

                Toggle("Font Thickening", isOn: Binding(
                    get: { viewModel.fontThicken },
                    set: { viewModel.fontThicken = $0 }
                ))

                if viewModel.fontThicken {
                    HStack {
                        Text("Thickening Strength")
                        Spacer()
                        Slider(
                            value: Binding(
                                get: { Double(viewModel.fontThickenStrength) },
                                set: { viewModel.fontThickenStrength = Int($0) }
                            ),
                            in: 0...255,
                            step: 1
                        )
                        .frame(width: 140)
                        Text("\(viewModel.fontThickenStrength)")
                            .font(.callout.monospacedDigit())
                            .frame(width: 36, alignment: .trailing)
                    }
                }
            } header: {
                Label("Rendering & Features", systemImage: "wand.and.stars")
            }

            // MARK: - Cell Metrics Adjustments
            Section {
                cellWidthRow
                cellHeightRow
                fontBaselineRow
            } header: {
                Label("Cell Dimensions & Alignment", systemImage: "ruler")
            } footer: {
                Text("Specify adjustments as percentage (e.g. 5%) or pixel offsets (e.g. 1, -1). Leave blank for Ghostty defaults.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - Live Preview
            Section {
                previewSection
            } header: {
                HStack {
                    Label("Typography Preview", systemImage: "eye")
                    Spacer()
                    Picker("", selection: $previewMode) {
                        ForEach(PreviewMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Typography")
    }

    // MARK: - Component Rows

    private var primaryFontRow: some View {
        HStack {
            Text("Font Family")
            Spacer()

            Picker("", selection: Binding(
                get: { viewModel.primaryFontFamily },
                set: { viewModel.primaryFontFamily = $0 }
            )) {
                let available = availableFontNames
                if !available.contains(viewModel.primaryFontFamily) {
                    Text(viewModel.primaryFontFamily).tag(viewModel.primaryFontFamily)
                }
                ForEach(available, id: \.self) { font in
                    Text(font).tag(font)
                }
            }
            .labelsHidden()
            .frame(minWidth: 200, maxWidth: 260)

            Button("Custom...") {
                customFontInput = viewModel.primaryFontFamily
                showCustomFontSheet = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .sheet(isPresented: $showCustomFontSheet) {
                customFontSheetView
            }
        }
    }

    private var fontSizeRow: some View {
        HStack(spacing: 16) {
            Text("Size")
            Slider(
                value: Binding(
                    get: { viewModel.fontSize },
                    set: { viewModel.fontSize = $0 }
                ),
                in: 8...36,
                step: 0.5
            )

            HStack(spacing: 4) {
                Text(String(format: viewModel.fontSize.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f pt" : "%.1f pt", viewModel.fontSize))
                    .font(.callout.monospacedDigit().weight(.medium))
                    .frame(width: 60, alignment: .trailing)

                Stepper("", value: Binding(
                    get: { viewModel.fontSize },
                    set: { viewModel.fontSize = $0 }
                ), in: 6...72, step: 0.5)
                .labelsHidden()
            }
        }
    }

    private var fallbackFontsList: some View {
        Group {
            if viewModel.fallbackFontFamilies.isEmpty {
                Text("No fallback fonts configured. Ghostty will use system fallback glyphs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(Array(viewModel.fallbackFontFamilies.enumerated()), id: \.offset) { index, fallback in
                    HStack {
                        Label(fallback, systemImage: "arrow.turn.down.right")
                            .font(.callout.monospaced())
                        Spacer()
                        Text("#\(index + 1)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Capsule())

                        Button {
                            viewModel.removeFallbackFont(at: index)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 6)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var addFallbackFontRow: some View {
        HStack {
            Picker("Add Fallback", selection: $selectedNewFallback) {
                Text("Select a font to add...").tag("")
                ForEach(availableFontNames.filter { !viewModel.fallbackFontFamilies.contains($0) && $0 != viewModel.primaryFontFamily }, id: \.self) { font in
                    Text(font).tag(font)
                }
            }
            .labelsHidden()

            Button("Add") {
                if !selectedNewFallback.isEmpty {
                    viewModel.addFallbackFont(selectedNewFallback)
                    selectedNewFallback = ""
                }
            }
            .disabled(selectedNewFallback.isEmpty)
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var cellWidthRow: some View {
        HStack {
            Text("Adjust Cell Width")
            Spacer()
            TextField("Default (e.g. 5% or 1)", text: Binding(
                get: { viewModel.adjustCellWidth },
                set: { viewModel.adjustCellWidth = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 160)
            .font(.system(.body, design: .monospaced))
        }
    }

    private var cellHeightRow: some View {
        HStack {
            Text("Adjust Cell Height")
            Spacer()
            TextField("Default (e.g. 10% or 2)", text: Binding(
                get: { viewModel.adjustCellHeight },
                set: { viewModel.adjustCellHeight = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 160)
            .font(.system(.body, design: .monospaced))
        }
    }

    private var fontBaselineRow: some View {
        HStack {
            Text("Adjust Font Baseline")
            Spacer()
            TextField("Default (e.g. 1 or -1)", text: Binding(
                get: { viewModel.adjustFontBaseline },
                set: { viewModel.adjustFontBaseline = $0 }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 160)
            .font(.system(.body, design: .monospaced))
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(viewModel.primaryFontFamily) • \(String(format: "%.1f", viewModel.fontSize))pt")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                if !viewModel.ligaturesEnabled {
                    Text("Ligatures Off")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Text(previewText)
                .font(.custom(viewModel.primaryFontFamily, size: CGFloat(viewModel.fontSize), relativeTo: .body))
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
        }
        .padding(.vertical, 4)
    }

    private var customFontSheetView: some View {
        VStack(spacing: 16) {
            Text("Enter Custom Font Name")
                .font(.headline)

            TextField("e.g. JetBrains Mono, Fira Code", text: $customFontInput)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)

            HStack(spacing: 12) {
                Button("Cancel") {
                    showCustomFontSheet = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Set Font") {
                    let trimmed = customFontInput.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        viewModel.primaryFontFamily = trimmed
                    }
                    showCustomFontSheet = false
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
                Text("Typography changes are held in-memory.")
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

    private var availableFontNames: [String] {
        let discovered = viewModel.fontsState.fonts.map(\.name)
        if !discovered.isEmpty {
            return discovered
        }
        // Fallback default system coding fonts
        return [
            "Menlo",
            "Monaco",
            "Courier New",
            "SF Mono",
            "JetBrains Mono",
            "Hack",
            "Fira Code"
        ]
    }

    private var previewText: String {
        switch previewMode {
        case .code:
            return """
            // Ghostty Typography Preview
            fn calculate_metrics(size: f32) -> Result<f32, Error> {
                if size <= 0.0 || size != 13.0 {
                    return Err(Error::InvalidSize);
                }
                let ratio = 1.618;
                Ok(size * ratio)
            }
            """
        case .symbols:
            return """
            Ligatures & Operators:
            != == === >= <= => -> <- <-> <>
            && || :: ?: /* */ <!-- -->
            0123456789 () [] {} <> ~@#$%^&*+-=/
            """
        case .text:
            return """
            The quick brown fox jumps over the lazy dog.
            1234567890 - Regular, Bold, and Italic.
            PACK MY BOX WITH FIVE DOZEN LIQUOR JUGS.
            """
        }
    }
}
