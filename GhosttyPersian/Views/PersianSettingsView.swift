import SwiftUI

/// View managing Persian/Farsi typography optimization, Vazirmatn font fallback injection, cell clipping prevention, and RTL guidance.
public struct PersianSettingsView: View {
    @Environment(AppViewModel.self) private var environmentViewModel: AppViewModel?
    @State private var fallbackViewModel = AppViewModel()

    private var viewModel: AppViewModel {
        environmentViewModel ?? fallbackViewModel
    }

    @State private var selectedPersianFont: String = ""
    @State private var previewMode: PersianPreviewMode = .prose
    @State private var selectedPreset: PersianPreset = .standard
    @State private var showPresetSheet: Bool = false

    private enum PersianPreviewMode: String, CaseIterable, Identifiable {
        case prose = "Prose"
        case mixed = "Mixed Code"
        case digits = "Numbers"
        case prompt = "Terminal"

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

            // MARK: - One-Click Persian Optimization Preset
            Section {
                persianPresetRow
            } header: {
                Label("One-Click Persian Optimization", systemImage: "wand.and.stars")
            } footer: {
                Text("Applies a battle-tested configuration for Persian terminal usage: Vazirmatn font, 15% cell expansion to prevent diacritic clipping, and balanced window padding.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - Persian Font Status & Detection
            Section {
                vazirFamilyStatusRow
                installedPersianFontsRow
            } header: {
                Label("Persian Font Detection", systemImage: "textformat")
            } footer: {
                if !viewModel.persianReport.isVazirFamilyInstalled {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        Text("Vazirmatn is the recommended open-source Persian font for terminals.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Link("Get Vazirmatn", destination: URL(string: "https://fonts.google.com/specimen/Vazirmatn")!)
                            .font(.caption.weight(.medium))
                    }
                    .padding(.top, 2)
                }
            }

            // MARK: - Persian Font Role in Ghostty
            Section {
                configuredStatusRow
                fontSelectionRow
                fontRoleActionsRow
            } header: {
                Label("Persian Font Setup", systemImage: "character.textbox")
            } footer: {
                Text("Using Persian as a fallback font is recommended for programming: your preferred Latin font handles ASCII code, while the Persian font renders Persian characters seamlessly.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - Persian Script Metrics & Clipping Prevention
            Section {
                metricsExplanationRow
                metricsControlsRow
            } header: {
                Label("Persian Metrics & Clipping Prevention", systemImage: "ruler")
            } footer: {
                Text("Persian letters have deeper descenders and under-dots (پ، چ، ی) that can clip in tight monospace cells. Applying a 15% cell height with a +1 baseline offset resolves clipping.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - Technical RTL & Shaping Guidance
            Section {
                rtlGuidanceRow
            } header: {
                Label("Ghostty RTL & Shaping Information", systemImage: "info.circle")
            }

            // MARK: - Interactive Preview
            Section {
                previewSection
            } header: {
                HStack {
                    Label("Persian Typography Preview", systemImage: "eye")
                    Spacer()
                    Picker("", selection: $previewMode) {
                        ForEach(PersianPreviewMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Persian")
        .onAppear {
            if selectedPersianFont.isEmpty {
                selectedPersianFont = viewModel.configuredPersianFontName
                    ?? viewModel.persianReport.recommendedFontName
                    ?? "Vazir"
            }
        }
        .sheet(isPresented: $showPresetSheet) {
            presetDiffSheet
        }
    }

    // MARK: - Preset Controls & Diff Sheet

    private var persianPresetRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedPreset.name)
                        .font(.headline)
                    Text(selectedPreset.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showPresetSheet = true
                } label: {
                    Label("Review & Apply Preset...", systemImage: "wand.and.stars")
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            HStack {
                Text("Preset Style")
                    .font(.subheadline)
                Spacer()
                Picker("", selection: $selectedPreset) {
                    ForEach(PersianPreset.allPresets) { preset in
                        Text(preset.name).tag(preset)
                    }
                }
                .labelsHidden()
                .frame(minWidth: 260)
            }
        }
        .padding(.vertical, 4)
    }

    private var presetDiffSheet: some View {
        VStack(spacing: 0) {
            // Sheet Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Apply Persian Preset")
                        .font(.title2.weight(.bold))
                    Text("Review the configuration changes before applying them to in-memory state.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showPresetSheet = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            // Changes Table
            let changes = viewModel.previewPersianPresetChanges(preset: selectedPreset)
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(changes) { item in
                        HStack(spacing: 12) {
                            Text(item.key)
                                .font(.system(.body, design: .monospaced).weight(.semibold))
                                .frame(width: 200, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text("Current:")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(item.currentValue ?? "Default / Unset")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(item.currentValue == nil ? .secondary : .primary)
                                }
                                HStack(spacing: 4) {
                                    Text("Proposed:")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(item.proposedValue)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(Color.accentColor)
                                }
                            }

                            Spacer()

                            if item.isModified {
                                Text(item.currentValue == nil ? "New" : "Modified")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(item.currentValue == nil ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                    .foregroundStyle(item.currentValue == nil ? Color.green : Color.orange)
                                    .clipShape(Capsule())
                            } else {
                                Text("Unchanged")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.12))
                                    .foregroundStyle(.secondary)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(item.isModified ? Color.accentColor.opacity(0.04) : Color.clear)

                        Divider()
                    }
                }
                .padding(.vertical, 8)
            }
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Footer Actions
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "shield.checkmark")
                        .foregroundStyle(.green)
                    Text("Non-destructive: custom options and comments will be preserved.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Cancel") {
                    showPresetSheet = false
                }
                .buttonStyle(.bordered)

                Button {
                    viewModel.applyPersianPreset(preset: selectedPreset)
                    showPresetSheet = false
                } label: {
                    Text("Apply Preset in Memory")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 620, minHeight: 460)
    }

    // MARK: - Component Rows

    private var vazirFamilyStatusRow: some View {
        LabeledContent("Vazir / Vazirmatn") {
            if viewModel.persianReport.isVazirFamilyInstalled {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Installed on System")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.green)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Not Installed Locally")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var installedPersianFontsRow: some View {
        LabeledContent("Available Fonts") {
            let installed = viewModel.persianReport.installedFonts
            if installed.isEmpty {
                Text("None detected (System fallback will be used)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 6) {
                    ForEach(installed.prefix(4)) { font in
                        Text(font.name)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    if installed.count > 4 {
                        Text("+\(installed.count - 4) more")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var configuredStatusRow: some View {
        LabeledContent("Current Configuration") {
            if let configured = viewModel.configuredPersianFontName {
                HStack(spacing: 8) {
                    Text(configured)
                        .font(.callout.monospaced().weight(.semibold))

                    if viewModel.isPersianPrimary {
                        Text("Primary Font")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    } else if viewModel.isPersianFallback {
                        Text("Fallback Font")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }
            } else {
                Text("Not configured in Ghostty")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var fontSelectionRow: some View {
        HStack {
            Text("Select Font")
            Spacer()
            Picker("", selection: $selectedPersianFont) {
                let options = availableOptions
                ForEach(options, id: \.self) { font in
                    Text(font).tag(font)
                }
            }
            .labelsHidden()
            .frame(minWidth: 200, maxWidth: 260)
        }
    }

    private var fontRoleActionsRow: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.addPersianAsFallback(fontName: selectedPersianFont)
            } label: {
                Label("Set as Fallback (Recommended)", systemImage: "arrow.turn.down.right")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            Button {
                viewModel.setPersianAsPrimary(fontName: selectedPersianFont)
            } label: {
                Label("Set as Primary", systemImage: "textformat")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            if viewModel.isPersianConfigured {
                Button(role: .destructive) {
                    if let configured = viewModel.configuredPersianFontName {
                        viewModel.removePersianFont(fontName: configured)
                    }
                } label: {
                    Label("Remove", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
        .padding(.vertical, 4)
    }

    private var metricsExplanationRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Recommended Persian Alignment")
                    .font(.headline)
                Text("Sets adjust-cell-height = 15% and adjust-font-baseline = 1 to give Persian dots and descenders room without text truncation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                viewModel.applyRecommendedPersianMetrics()
            } label: {
                if viewModel.areRecommendedPersianMetricsApplied {
                    Label("Optimized", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("Apply Optimization", systemImage: "wand.and.stars")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .padding(.vertical, 4)
    }

    private var metricsControlsRow: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Cell Height Adjustment")
                Spacer()
                TextField("Default", text: Binding(
                    get: { viewModel.adjustCellHeight },
                    set: { viewModel.adjustCellHeight = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 140)
                .font(.system(.body, design: .monospaced))
            }

            HStack {
                Text("Font Baseline Offset")
                Spacer()
                TextField("Default", text: Binding(
                    get: { viewModel.adjustFontBaseline },
                    set: { viewModel.adjustFontBaseline = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 140)
                .font(.system(.body, design: .monospaced))
            }
        }
    }

    private var rtlGuidanceRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Cursive Letter Shaping (Native macOS CoreText)")
                        .font(.callout.weight(.semibold))
                    Text("Connecting Persian letters (مانند بـ، ـهـ، ـی) shape naturally via CoreText inside Ghostty on macOS.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bidirectional Text Ordering (BiDi)")
                        .font(.callout.weight(.semibold))
                    Text("Ghostty does not yet provide terminal-level RTL paragraph reordering. For bidirectional text, CLI tools with built-in BiDi support (e.g. fribidi, bicon, or specialized text utilities) should be used.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(effectivePreviewFontName) • \(String(format: "%.1f", viewModel.fontSize))pt")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("فارسی / Persian")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Text(previewText)
                .font(.custom(effectivePreviewFontName, size: CGFloat(viewModel.fontSize), relativeTo: .body))
                .lineSpacing(6)
                .multilineTextAlignment(.leading)
                .environment(\.layoutDirection, previewLayoutDirection)
                .frame(maxWidth: .infinity, alignment: previewAlignment)
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

    private var changeStatusBar: some View {
        HStack {
            Image(systemName: "pencil.circle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Unsaved Changes")
                    .font(.headline)
                Text("Persian configuration adjustments are held in memory.")
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

    private var effectivePreviewFontName: String {
        if !selectedPersianFont.isEmpty {
            return selectedPersianFont
        }
        return viewModel.configuredPersianFontName ?? "Vazir"
    }

    private var availableOptions: [String] {
        var names = viewModel.persianReport.installedFonts.map(\.name)
        if !names.contains("Vazirmatn") {
            names.append("Vazirmatn")
        }
        if !names.contains("Vazir") {
            names.append("Vazir")
        }
        if !names.contains("IRANSansWeb") {
            names.append("IRANSansWeb")
        }
        if !names.contains("Yekan Bakh") {
            names.append("Yekan Bakh")
        }
        return names
    }

    private var previewLayoutDirection: LayoutDirection {
        switch previewMode {
        case .prose:
            return .rightToLeft
        case .mixed, .digits, .prompt:
            return .leftToRight
        }
    }

    private var previewAlignment: Alignment {
        switch previewMode {
        case .prose:
            return .trailing
        case .mixed, .digits, .prompt:
            return .leading
        }
    }

    private var previewText: String {
        switch previewMode {
        case .prose:
            return """
            به نام خداوند جان و خرد
            کزین برتر اندیشه برنگذرد
            خداوند نام و خداوند جای
            خداوند روزی‌ده رهنمای
            گستی پرشین • پایانه مدرن با پشتیبانی از خط فارسی
            """
        case .mixed:
            return """
            // نمونه کد حاوی متن و رشته‌های فارسی
            let greeting = "سلام دنیا! Persian Ghostty";
            func چاپ_پیام(متن: String) {
                print("پیام کاربر: \\(متن)"); // خروجی استاندارد
            }
            """
        case .digits:
            return """
            ارقام فارسی:  ۰ ۱ ۲ ۳ ۴ ۵ ۶ ۷ ۸ ۹
            Western:      0 1 2 3 4 5 6 7 8 9
            تاریخ و زمان: ۱۴۰۵/۰۷/۱۰ • ۱۲:۳۴:۵۶
            Port: 8080 • IP: 192.168.1.100
            """
        case .prompt:
            return """
            mac@GhosttyPersian ~ % cd ~/پروژه‌ها/گوستی
            mac@GhosttyPersian گوستی % git status
            روی شاخه main • هیچ تغییری ثبت نشده است.
            mac@GhosttyPersian گوستی % echo "موفقیت‌آمیز"
            موفقیت‌آمیز
            """
        }
    }
}
