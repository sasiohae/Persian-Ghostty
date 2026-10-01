import Foundation

extension AppViewModel {
    // MARK: - Persian Font Discovery & Status

    /// Discovers and reports installed and recommended Persian fonts on the system.
    public var persianReport: PersianDetectionReport {
        SystemPersianFontDetector().detectFonts()
    }

    /// Whether any Persian font is currently configured as either primary or fallback font.
    public var isPersianConfigured: Bool {
        configuredPersianFontName != nil
    }

    /// The name of the currently configured Persian font if one is present.
    public var configuredPersianFontName: String? {
        let allFonts = [primaryFontFamily] + fallbackFontFamilies
        let persianNames = Set(SystemPersianFontDetector.standardCandidates.map(\.name))

        for font in allFonts {
            if persianNames.contains(font) || font.localizedCaseInsensitiveContains("vazir") || font.localizedCaseInsensitiveContains("yekan") || font.localizedCaseInsensitiveContains("iransans") {
                return font
            }
        }
        return nil
    }

    /// Whether the primary terminal font is a Persian font.
    public var isPersianPrimary: Bool {
        guard let configured = configuredPersianFontName else { return false }
        return primaryFontFamily == configured
    }

    /// Whether a Persian font is configured as a fallback font.
    public var isPersianFallback: Bool {
        guard let configured = configuredPersianFontName else { return false }
        return fallbackFontFamilies.contains(configured)
    }

    // MARK: - Persian Configuration Actions

    /// Sets the specified Persian font as the primary terminal font.
    public func setPersianAsPrimary(fontName: String) {
        let trimmed = fontName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // Remove from fallback list if previously present
        var fallbacks = fallbackFontFamilies
        fallbacks.removeAll { $0 == trimmed }

        // Update primary and preserve cleaned fallbacks
        primaryFontFamily = trimmed
        fallbackFontFamilies = fallbacks
    }

    /// Injects or moves the specified Persian font into Ghostty's fallback font list.
    public func addPersianAsFallback(fontName: String) {
        let trimmed = fontName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        // If it was primary, revert primary to default coding font
        if primaryFontFamily == trimmed {
            primaryFontFamily = "Monaco"
        }

        var fallbacks = fallbackFontFamilies
        if !fallbacks.contains(trimmed) {
            fallbacks.append(trimmed)
            fallbackFontFamilies = fallbacks
        }
    }

    /// Removes a Persian font from both primary and fallback roles.
    public func removePersianFont(fontName: String) {
        let trimmed = fontName.trimmingCharacters(in: .whitespaces)
        if primaryFontFamily == trimmed {
            primaryFontFamily = "Monaco"
        }
        var fallbacks = fallbackFontFamilies
        fallbacks.removeAll { $0 == trimmed }
        fallbackFontFamilies = fallbacks
    }

    /// Applies recommended cell dimension adjustments tailored for Persian script rendering.
    public func applyRecommendedPersianMetrics() {
        adjustCellHeight = "15%"
        adjustFontBaseline = "1"
        fontThicken = true
    }

    /// Checks whether Persian cell height and baseline optimizations are currently configured.
    public var areRecommendedPersianMetricsApplied: Bool {
        adjustCellHeight == "15%" && adjustFontBaseline == "1"
    }

    // MARK: - Persian Preset Application

    /// Computes the precise configuration key differences that will occur when applying a preset.
    public func previewPersianPresetChanges(preset: PersianPreset = .standard) -> [PresetChangeItem] {
        PersianPresetService().previewChanges(for: preset, on: currentDocument)
    }

    /// Safely applies the curated Persian preset to the in-memory document without committing to disk.
    @discardableResult
    public func applyPersianPreset(preset: PersianPreset = .standard) -> [PresetChangeItem] {
        var changes: [PresetChangeItem] = []
        updateDocument { doc in
            changes = PersianPresetService().apply(preset: preset, to: &doc)
        }
        return changes
    }

    // MARK: - Interactive Shell & BiDi Integration

    /// Detected active shell type (e.g. zsh, fish).
    public var detectedShellType: PersianShellType {
        persianShellService.detectActiveShell()
    }

    /// Status of Persian shell integration for the specified shell (or detected active shell).
    public func getPersianShellStatus(for shell: PersianShellType? = nil) -> PersianShellStatus {
        let target = shell ?? detectedShellType
        return persianShellService.getStatus(for: target)
    }

    /// Whether Persian shell integration is currently installed for the specified shell (or detected active shell).
    public func isPersianShellInstalled(for shell: PersianShellType? = nil) -> Bool {
        let target = shell ?? detectedShellType
        return persianShellService.isInstalled(for: target)
    }

    /// Safely installs the Persian interactive shell integration.
    @discardableResult
    public func installPersianShellIntegration(for shell: PersianShellType? = nil) -> Bool {
        let target = shell ?? detectedShellType
        do {
            let url = try persianShellService.install(for: target)
            showToast(
                title: "Shell Integration Installed",
                message: "Added Persian BiDi & RTL helpers to \(url.lastPathComponent)."
            )
            return true
        } catch {
            showToast(
                title: "Installation Failed",
                message: error.localizedDescription,
                isError: true
            )
            return false
        }
    }

    /// Safely removes the Persian interactive shell integration.
    @discardableResult
    public func removePersianShellIntegration(for shell: PersianShellType? = nil) -> Bool {
        let target = shell ?? detectedShellType
        do {
            let removed = try persianShellService.remove(for: target)
            if removed {
                showToast(
                    title: "Shell Integration Removed",
                    message: "Cleaned Persian helpers from \(target.displayName) configuration."
                )
            }
            return removed
        } catch {
            showToast(
                title: "Removal Failed",
                message: error.localizedDescription,
                isError: true
            )
            return false
        }
    }
}
