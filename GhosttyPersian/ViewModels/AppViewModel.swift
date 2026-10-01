import Foundation
import Observation

/// Root application ViewModel coordinating configuration state, Ghostty CLI interactions, and safe persistence.
@Observable
@MainActor
public final class AppViewModel: @unchecked Sendable {
    // MARK: - Dependencies

    public let repository: GhosttyConfigRepositoryProtocol
    public let cliService: GhosttyCLIServiceProtocol
    public let workspaceOpener: WorkspaceOpening

    // MARK: - State

    /// Current loading state of configuration file.
    public private(set) var loadingState: ConfigurationLoadingState = .idle

    /// The working in-memory configuration document reflecting pending edits.
    public private(set) var currentDocument: GhosttyConfigDocument = GhosttyConfigDocument()

    /// The baseline document matching disk content (or nil if no config existed).
    public private(set) var originalDocument: GhosttyConfigDocument? = nil

    /// Discovered effective configuration path or recommended default.
    public private(set) var effectivePath: GhosttyConfigPath? = nil

    /// Whether a configuration file currently exists on disk.
    public private(set) var configExists: Bool = false

    /// Real-time or last known validation state.
    public private(set) var validationState: ValidationState = .unknown

    /// Current save / backup progress or outcome.
    public private(set) var saveState: SaveState = .idle

    /// Ghostty CLI availability, executable path, and version info.
    public private(set) var cliStatus: GhosttyCLIStatus = .unavailable

    /// Discovered fonts state.
    public private(set) var fontsState: FontsState = FontsState()

    /// Discovered themes state.
    public private(set) var themesState: ThemesState = ThemesState()

    /// Available backup history.
    public private(set) var backups: [GhosttyBackupInfo] = []

    /// Notification data for transient UI toasts.
    public struct ToastNotification: Identifiable, Sendable, Equatable {
        public let id: UUID
        public let title: String
        public let message: String
        public let isError: Bool

        public init(id: UUID = UUID(), title: String, message: String, isError: Bool = false) {
            self.id = id
            self.title = title
            self.message = message
            self.isError = isError
        }
    }

    /// Currently active toast notification.
    public private(set) var activeToast: ToastNotification? = nil

    /// Currently active structured diagnostic report for errors.
    public private(set) var activeDiagnostic: AppDiagnosticReport? = nil

    /// Shows a transient toast notification.
    public func showToast(title: String, message: String, isError: Bool = false) {
        activeToast = ToastNotification(title: title, message: message, isError: isError)
    }

    /// Dismisses the active toast notification.
    public func dismissToast() {
        activeToast = nil
    }

    /// Displays a structured diagnostic report.
    public func showDiagnostic(_ report: AppDiagnosticReport) {
        activeDiagnostic = report
    }

    /// Dismisses the active diagnostic report.
    public func dismissDiagnostic() {
        activeDiagnostic = nil
    }

    // MARK: - Computed Properties

    /// Whether there are unsaved modifications in the active configuration document.
    public var isDirty: Bool {
        if let original = originalDocument {
            return currentDocument != original
        }
        return !currentDocument.lines.isEmpty
    }

    /// Candidate configuration paths discovered on the filesystem.
    public var candidatePaths: [GhosttyConfigPath] {
        repository.pathResolver.candidatePaths()
    }

    // MARK: - Initialization

    public init(
        repository: GhosttyConfigRepositoryProtocol = GhosttyConfigRepository(),
        cliService: GhosttyCLIServiceProtocol = GhosttyCLIService(),
        workspaceOpener: WorkspaceOpening = DefaultWorkspaceOpener()
    ) {
        self.repository = repository
        self.cliService = cliService
        self.workspaceOpener = workspaceOpener
    }

    // MARK: - Lifecycle

    /// Loads initial status, configuration, and asynchronously discovers fonts/themes.
    public func loadInitialData() async {
        await checkCLIStatus()
        await loadConfiguration()
        loadBackups()

        if cliStatus.isAvailable {
            async let fontsTask: Void = loadFonts()
            async let themesTask: Void = loadThemes()
            _ = await (fontsTask, themesTask)
        }
    }

    /// Verifies Ghostty CLI presence and extracts version information.
    public func checkCLIStatus() async {
        let isInstalled = cliService.isGhosttyInstalled()
        guard isInstalled else {
            cliStatus = .unavailable
            return
        }

        let execURL = try? cliService.executableURL()
        let version = try? cliService.getVersion()

        cliStatus = GhosttyCLIStatus(
            isAvailable: true,
            executableURL: execURL,
            version: version,
            errorMessage: nil
        )
    }

    /// Discovers and loads the active configuration according to precedence rules.
    public func loadConfiguration() async {
        loadingState = .loading

        do {
            if let loaded = try repository.loadEffectiveConfiguration() {
                effectivePath = loaded.path
                configExists = loaded.path.exists
                originalDocument = loaded.document
                currentDocument = loaded.document
                loadingState = .loaded(loaded)

                // Validate loaded configuration in background if CLI is ready
                if cliStatus.isAvailable {
                    _ = await validateCurrentDocument()
                } else {
                    validationState = .unknown
                }
            } else {
                let defaultPath = repository.pathResolver.defaultRecommendedPath
                effectivePath = GhosttyConfigPath(
                    url: defaultPath,
                    scope: .macOS,
                    exists: false,
                    precedenceOrder: 4
                )
                configExists = false
                originalDocument = nil
                currentDocument = GhosttyConfigDocument()
                loadingState = .notFound(recommendedPath: defaultPath)
                validationState = .unknown
            }
        } catch {
            loadingState = .failed(error.localizedDescription)
        }
    }

    /// Fetches all fonts supported by Ghostty.
    public func loadFonts() async {
        fontsState = FontsState(isLoading: true, fonts: fontsState.fonts, error: nil)
        do {
            let fonts = try cliService.listFonts()
            fontsState = FontsState(isLoading: false, fonts: fonts, error: nil)
        } catch {
            fontsState = FontsState(isLoading: false, fonts: [], error: error.localizedDescription)
        }
    }

    /// Fetches all themes supported by Ghostty.
    public func loadThemes(colorScheme: GhosttyThemeColorScheme = .all) async {
        themesState = ThemesState(isLoading: true, themes: themesState.themes, error: nil)
        do {
            let themes = try cliService.listThemes(colorScheme: colorScheme)
            themesState = ThemesState(isLoading: false, themes: themes, error: nil)
        } catch {
            themesState = ThemesState(isLoading: false, themes: [], error: error.localizedDescription)
        }
    }

    // MARK: - In-Memory Document Manipulation

    /// Updates or sets a configuration setting in memory without writing to disk.
    public func updateSetting(key: String, value: String, isQuoted: Bool = false) {
        currentDocument.setValue(key: key, value: value, isQuoted: isQuoted)
        validationState = .unknown
        saveState = .idle
    }

    /// Removes a configuration setting from the in-memory document.
    public func removeSetting(key: String) {
        currentDocument.removeKey(key)
        validationState = .unknown
        saveState = .idle
    }

    /// Sets repeated configuration settings (e.g. font fallback list) in memory.
    public func setRepeatedSettings(key: String, values: [String], isQuoted: Bool = false) {
        currentDocument.setRepeatedValues(key: key, values: values, isQuoted: isQuoted)
        validationState = .unknown
        saveState = .idle
    }

    /// Safely modifies the in-memory document via a closure and resets validation/save states.
    public func updateDocument(_ modifier: (inout GhosttyConfigDocument) -> Void) {
        modifier(&currentDocument)
        validationState = .unknown
        saveState = .idle
    }

    /// Reads the effective logical value for a setting from the in-memory document.
    public func getEffectiveValue(for key: String) -> String? {
        currentDocument.effectiveValue(for: key)
    }

    /// Reads all logical values for a repeated key from the in-memory document.
    public func getAllValues(for key: String) -> [String] {
        currentDocument.allValues(for: key)
    }

    /// Discards in-memory edits and reverts to the last saved or loaded state.
    public func resetChanges() {
        currentDocument = originalDocument ?? GhosttyConfigDocument()
        validationState = .unknown
        saveState = .idle
    }

    // MARK: - Validation & Saving

    /// Validates the current in-memory document using Ghostty CLI against a staging file.
    @discardableResult
    public func validateCurrentDocument() async -> GhosttyValidationResult? {
        guard cliStatus.isAvailable else {
            validationState = .skipped(reason: "Ghostty CLI is not available")
            return nil
        }

        validationState = .validating

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("GhosttyValidate-\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            validationState = .invalid([], rawOutput: "Failed to create temporary directory for validation: \(error.localizedDescription)")
            return nil
        }
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let stagingURL = tempDir.appendingPathComponent("config.ghostty")
        let serialized = currentDocument.serialize()

        do {
            try serialized.write(to: stagingURL, atomically: true, encoding: .utf8)
            let result = try cliService.validateConfig(at: stagingURL)
            if result.isValid {
                validationState = .valid
                activeDiagnostic = nil
            } else {
                validationState = .invalid(result.issues, rawOutput: result.rawOutput)
                activeDiagnostic = DiagnosticService.createReport(
                    from: GhosttyConfigRepositoryError.validationFailed(issues: result.issues, rawOutput: result.rawOutput),
                    targetURL: effectivePath?.url
                )
            }
            return result
        } catch {
            validationState = .invalid([], rawOutput: error.localizedDescription)
            activeDiagnostic = DiagnosticService.createReport(from: error, targetURL: effectivePath?.url)
            return nil
        }
    }

    /// Safely saves the working document to disk via the repository layer.
    @discardableResult
    public func saveConfiguration(createBackup: Bool = true, validate: Bool = true) async -> Bool {
        saveState = .saving
        let targetURL = effectivePath?.url

        do {
            let result = try repository.saveConfiguration(
                document: currentDocument,
                to: targetURL,
                createBackup: createBackup,
                validate: validate
            )

            originalDocument = currentDocument
            configExists = true
            saveState = .saved(result)
            loadBackups()
            activeDiagnostic = nil

            if let val = result.validationResult {
                validationState = val.isValid ? .valid : .invalid(val.issues, rawOutput: val.rawOutput)
            } else {
                validationState = .valid
            }
            showToast(title: "Configuration Saved", message: "Successfully wrote changes to \(result.targetURL.lastPathComponent).")
            return true
        } catch let error as GhosttyConfigRepositoryError {
            saveState = .failed(error.localizedDescription)
            if case .validationFailed(let issues, let raw) = error {
                validationState = .invalid(issues, rawOutput: raw)
            }
            activeDiagnostic = DiagnosticService.createReport(from: error, targetURL: targetURL)
            showToast(title: "Save Failed", message: error.localizedDescription, isError: true)
            return false
        } catch {
            saveState = .failed(error.localizedDescription)
            activeDiagnostic = DiagnosticService.createReport(from: error, targetURL: targetURL)
            showToast(title: "Save Failed", message: error.localizedDescription, isError: true)
            return false
        }
    }

    /// Reloads configuration from disk, discarding any unsaved in-memory edits.
    public func reloadFromDisk() async {
        await loadConfiguration()
        loadBackups()
        showToast(title: "Configuration Reloaded", message: "Reloaded settings from disk.")
    }

    // MARK: - Backups Management

    /// Loads the list of existing backups from the repository.
    public func loadBackups() {
        backups = (try? repository.listBackups()) ?? []
    }

    /// Restores a configuration from an existing backup file.
    @discardableResult
    public func restoreBackup(_ backup: GhosttyBackupInfo, validate: Bool = true) async -> Bool {
        saveState = .saving
        do {
            let result = try repository.restoreBackup(from: backup.url, to: effectivePath?.url, validate: validate)
            await loadConfiguration()
            loadBackups()
            saveState = .saved(result)
            activeDiagnostic = nil
            showToast(title: "Backup Restored", message: "Restored configuration from '\(backup.fileName)'.")
            return true
        } catch {
            saveState = .failed(error.localizedDescription)
            activeDiagnostic = DiagnosticService.createReport(from: error, targetURL: effectivePath?.url)
            showToast(title: "Restore Failed", message: error.localizedDescription, isError: true)
            return false
        }
    }

    /// Creates an immediate manual safety snapshot of the active configuration file.
    @discardableResult
    public func createManualBackup() -> GhosttyBackupInfo? {
        guard let url = effectivePath?.url, configExists else { return nil }
        do {
            let info = try repository.createBackup(for: url)
            loadBackups()
            showToast(title: "Backup Created", message: "Created snapshot '\(info.fileName)'.")
            return info
        } catch {
            activeDiagnostic = DiagnosticService.createReport(from: error, targetURL: url)
            showToast(title: "Backup Failed", message: error.localizedDescription, isError: true)
            return nil
        }
    }

    /// Deletes a specific backup snapshot.
    public func deleteBackup(_ backup: GhosttyBackupInfo) {
        do {
            try repository.deleteBackup(at: backup.url)
            loadBackups()
            showToast(title: "Backup Deleted", message: "Removed backup '\(backup.fileName)'.")
        } catch {
            activeDiagnostic = DiagnosticService.createReport(from: error, targetURL: backup.url)
            showToast(title: "Delete Failed", message: error.localizedDescription, isError: true)
        }
    }

    /// Prunes older backup snapshots, keeping only the specified count of newest backups.
    @discardableResult
    public func pruneBackups(keepLatest count: Int = 10) -> Int {
        do {
            let deleted = try repository.pruneBackups(keepLatest: count)
            loadBackups()
            return deleted
        } catch {
            return 0
        }
    }

    // MARK: - Workspace Actions

    /// Reveals the configuration file (or its parent directory) in Finder.
    public func openConfigurationInFinder() {
        guard let url = effectivePath?.url else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            workspaceOpener.activateFileViewerSelecting([url])
        } else {
            let parent = url.deletingLastPathComponent()
            workspaceOpener.activateFileViewerSelecting([parent])
        }
    }

    /// Opens the configuration file in the user's default text editor.
    @discardableResult
    public func openConfigurationInEditor() -> Bool {
        guard let url = effectivePath?.url, FileManager.default.fileExists(atPath: url.path) else {
            return false
        }
        return workspaceOpener.open(url)
    }

    /// Reveals the detected Ghostty executable in Finder.
    public func openGhosttyBinaryInFinder() {
        guard let url = cliStatus.executableURL else { return }
        workspaceOpener.activateFileViewerSelecting([url])
    }

    /// Re-reads configuration from disk, discarding in-memory modifications.
    public func reloadConfiguration() async {
        await loadConfiguration()
    }
}
