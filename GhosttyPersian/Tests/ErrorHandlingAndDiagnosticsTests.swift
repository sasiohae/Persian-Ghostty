import XCTest
import SwiftUI
@testable import GhosttyPersian

@MainActor
final class ErrorHandlingAndDiagnosticsTests: XCTestCase {

    // MARK: - 1. Diagnostic Domain & Model Tests

    func testDiagnosticDomainProperties() {
        XCTAssertEqual(DiagnosticDomain.cli.id, "Ghostty CLI")
        XCTAssertEqual(DiagnosticDomain.validation.id, "Validation")
        XCTAssertEqual(DiagnosticDomain.filesystem.id, "File System")
        XCTAssertEqual(DiagnosticDomain.permissions.id, "Permissions")
        XCTAssertEqual(DiagnosticDomain.backup.id, "Backup & Recovery")
        XCTAssertEqual(DiagnosticDomain.general.id, "General")

        XCTAssertEqual(DiagnosticDomain.cli.iconName, "terminal")
        XCTAssertEqual(DiagnosticDomain.validation.iconName, "exclamationmark.shield")
        XCTAssertEqual(DiagnosticDomain.filesystem.iconName, "folder.badge.gearshape")
        XCTAssertEqual(DiagnosticDomain.permissions.iconName, "lock.trianglebadge.exclamationmark")
        XCTAssertEqual(DiagnosticDomain.backup.iconName, "clock.arrow.circlepath")
        XCTAssertEqual(DiagnosticDomain.general.iconName, "exclamationmark.circle")
    }

    func testDiagnosticActionEqualityAndProperties() {
        let action1 = DiagnosticAction(
            title: "Revert",
            systemImage: "arrow.uturn.backward",
            kind: .revertChanges,
            isDestructive: true
        )
        let action2 = DiagnosticAction(
            title: "Revert",
            systemImage: "arrow.uturn.backward",
            kind: .revertChanges,
            isDestructive: true
        )
        let action3 = DiagnosticAction(
            title: "Restore",
            systemImage: "clock.arrow.circlepath",
            kind: .restoreLastBackup,
            isDestructive: false
        )

        XCTAssertEqual(action1, action2)
        XCTAssertNotEqual(action1, action3)
        XCTAssertEqual(action1.id, "Revert")
        XCTAssertTrue(action1.isDestructive)
        XCTAssertFalse(action3.isDestructive)
    }

    func testAppDiagnosticReportFormattingForClipboard() {
        let action = DiagnosticAction(title: "Dismiss", systemImage: "xmark", kind: .dismiss)
        let report = AppDiagnosticReport(
            title: "Test Error",
            summary: "A test error occurred.",
            rootCause: "Network connection lost.",
            recoverySuggestion: "Reconnect and try again.",
            domain: .general,
            technicalDetails: "Code 503 Service Unavailable",
            actions: [action]
        )

        let formatted = report.formattedReportForClipboard
        XCTAssertTrue(formatted.contains("--- GHOSTTY PERSIAN DIAGNOSTIC REPORT ---"))
        XCTAssertTrue(formatted.contains("Domain: General"))
        XCTAssertTrue(formatted.contains("Title: Test Error"))
        XCTAssertTrue(formatted.contains("Summary:\nA test error occurred."))
        XCTAssertTrue(formatted.contains("Root Cause:\nNetwork connection lost."))
        XCTAssertTrue(formatted.contains("Suggested Action:\nReconnect and try again."))
        XCTAssertTrue(formatted.contains("Code 503 Service Unavailable"))
    }

    // MARK: - 2. DiagnosticService ConfigRepository Mappings

    func testDiagnosticServiceValidationFailed() {
        let issues = [
            GhosttyValidationIssue(line: 12, message: "unknown setting 'font-bogus'")
        ]
        let repoError = GhosttyConfigRepositoryError.validationFailed(issues: issues, rawOutput: "syntax error on line 12")
        let targetURL = URL(fileURLWithPath: "/Users/test/.config/ghostty/config")

        let report = DiagnosticService.createReport(from: repoError, targetURL: targetURL)
        XCTAssertEqual(report.domain, DiagnosticDomain.validation)
        XCTAssertEqual(report.title, "Ghostty CLI Validation Failed")
        XCTAssertTrue(report.technicalDetails.contains("unknown setting 'font-bogus'"))
        XCTAssertTrue(report.actions.contains { $0.kind == DiagnosticActionKind.revertChanges })
        XCTAssertTrue(report.actions.contains { $0.kind == DiagnosticActionKind.restoreLastBackup })
        XCTAssertTrue(report.actions.contains { $0.kind == DiagnosticActionKind.revealInFinder(targetURL) })
    }

    func testDiagnosticServiceAtomicReplacementPermissionError() {
        let targetURL = URL(fileURLWithPath: "/Library/Application Support/ghostty/config")
        let error = GhosttyConfigRepositoryError.atomicReplacementFailed(
            targetURL: targetURL,
            underlyingError: "Permission denied writing to destination"
        )

        let report = DiagnosticService.createReport(from: error, targetURL: targetURL)
        XCTAssertEqual(report.domain, DiagnosticDomain.permissions)
        XCTAssertEqual(report.title, "Permission Denied Replacing Configuration")
        XCTAssertTrue(report.recoverySuggestion.contains("write access"))
        XCTAssertTrue(report.actions.contains { $0.kind == DiagnosticActionKind.revealInFinder(targetURL) })
        XCTAssertTrue(report.actions.contains { $0.kind == DiagnosticActionKind.revertChanges })
    }

    func testDiagnosticServiceAtomicReplacementFilesystemError() {
        let targetURL = URL(fileURLWithPath: "/tmp/config")
        let error = GhosttyConfigRepositoryError.atomicReplacementFailed(
            targetURL: targetURL,
            underlyingError: "No space left on device"
        )

        let report = DiagnosticService.createReport(from: error, targetURL: targetURL)
        XCTAssertEqual(report.domain, DiagnosticDomain.filesystem)
        XCTAssertEqual(report.title, "Configuration Replacement Failed")
        XCTAssertTrue(report.recoverySuggestion.contains("disk has sufficient space"))
    }

    func testDiagnosticServiceBackupFailed() {
        let targetURL = URL(fileURLWithPath: "/tmp/ghostty/config")
        let error = GhosttyConfigRepositoryError.backupFailed(
            targetURL: targetURL,
            underlyingError: "Read-only file system"
        )

        let report = DiagnosticService.createReport(from: error, targetURL: targetURL)
        XCTAssertEqual(report.domain, .backup)
        XCTAssertEqual(report.title, "Safety Backup Creation Failed")
        XCTAssertTrue(report.recoverySuggestion.contains("zero data loss"))
    }

    func testDiagnosticServiceStagingWriteFailed() {
        let tempURL = URL(fileURLWithPath: "/tmp/ghostty-staging.cfg")
        let error = GhosttyConfigRepositoryError.stagingWriteFailed(
            url: tempURL,
            underlyingError: "Disk quota exceeded"
        )

        let report = DiagnosticService.createReport(from: error, targetURL: tempURL)
        XCTAssertEqual(report.domain, .filesystem)
        XCTAssertEqual(report.title, "Staging File Creation Failed")
    }

    func testDiagnosticServiceCannotReadFile() {
        let url = URL(fileURLWithPath: "/nonexistent/config")
        let error = GhosttyConfigRepositoryError.cannotReadFile(
            url: url,
            underlyingError: "File not found"
        )

        let report = DiagnosticService.createReport(from: error, targetURL: url)
        XCTAssertEqual(report.domain, .filesystem)
        XCTAssertEqual(report.title, "Cannot Read Configuration File")
        XCTAssertTrue(report.actions.contains { $0.kind == .revealInFinder(url) })
    }

    func testDiagnosticServiceDirectoryCreationFailed() {
        let url = URL(fileURLWithPath: "/System/ghostty")
        let error = GhosttyConfigRepositoryError.directoryCreationFailed(
            url: url,
            underlyingError: "Operation not permitted"
        )

        let report = DiagnosticService.createReport(from: error, targetURL: url)
        XCTAssertEqual(report.domain, .filesystem)
        XCTAssertEqual(report.title, "Directory Creation Failed")
    }

    func testDiagnosticServiceConfigurationNotFound() {
        let paths = ["/Users/test/.config/ghostty/config", "/Users/test/Library/Application Support/ghostty/config"]
        let error = GhosttyConfigRepositoryError.configurationNotFound(searchedPaths: paths)

        let report = DiagnosticService.createReport(from: error)
        XCTAssertEqual(report.domain, .filesystem)
        XCTAssertEqual(report.title, "Configuration File Not Found")
        XCTAssertTrue(report.technicalDetails.contains("/Users/test/.config/ghostty/config"))
    }

    // MARK: - 3. DiagnosticService CLI Error Mappings

    func testDiagnosticServiceCLIExecutableNotFound() {
        let paths = ["/usr/local/bin/ghostty", "/Applications/Ghostty.app"]
        let error = GhosttyCLIError.executableNotFound(searchedPaths: paths)

        let report = DiagnosticService.createReport(from: error)
        XCTAssertEqual(report.domain, .cli)
        XCTAssertEqual(report.title, "Ghostty CLI Not Found")
        XCTAssertTrue(report.recoverySuggestion.contains("https://ghostty.org"))
    }

    func testDiagnosticServiceCLIExecutionFailed() {
        let error = GhosttyCLIError.executionFailed(command: "ghostty +validate-config", exitCode: 1, standardError: "fatal error: parse failure")

        let report = DiagnosticService.createReport(from: error)
        XCTAssertEqual(report.domain, DiagnosticDomain.cli)
        XCTAssertEqual(report.title, "Ghostty CLI Execution Failed")
        XCTAssertEqual(report.rootCause, "fatal error: parse failure")
    }

    func testDiagnosticServiceCLIProcessTimeout() {
        let error = GhosttyCLIError.processTimeout(command: "ghostty +list-fonts", timeout: 5.0)

        let report = DiagnosticService.createReport(from: error)
        XCTAssertEqual(report.domain, .cli)
        XCTAssertEqual(report.title, "CLI Command Timed Out")
        XCTAssertTrue(report.technicalDetails.contains("5.0s"))
    }

    func testDiagnosticServiceCLIInvalidOutput() {
        let error = GhosttyCLIError.invalidOutput(command: "ghostty +version", details: "unrecognized header format")

        let report = DiagnosticService.createReport(from: error)
        XCTAssertEqual(report.domain, .cli)
        XCTAssertEqual(report.title, "Unexpected CLI Output")
        XCTAssertEqual(report.rootCause, "unrecognized header format")
    }

    // MARK: - 4. DiagnosticService Generic / System Errors

    func testDiagnosticServiceCocoaPermissionError() {
        let nsError = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError, userInfo: [
            NSLocalizedDescriptionKey: "You don't have permission to save the file."
        ])

        let report = DiagnosticService.createReport(from: nsError)
        XCTAssertEqual(report.domain, .permissions)
        XCTAssertEqual(report.title, "Permission Denied")
    }

    func testDiagnosticServicePOSIXPermissionError() {
        let nsError = NSError(domain: NSPOSIXErrorDomain, code: 13, userInfo: [
            NSLocalizedDescriptionKey: "Permission denied (POSIX 13)"
        ])

        let report = DiagnosticService.createReport(from: nsError)
        XCTAssertEqual(report.domain, .permissions)
        XCTAssertEqual(report.title, "Permission Denied")
    }

    func testDiagnosticServiceGeneralFallbackError() {
        struct CustomError: LocalizedError {
            var errorDescription: String? { "Something went wrong in testing." }
        }

        let report = DiagnosticService.createReport(from: CustomError())
        XCTAssertEqual(report.domain, .general)
        XCTAssertEqual(report.title, "Unexpected Operation Error")
        XCTAssertEqual(report.summary, "Something went wrong in testing.")
    }

    // MARK: - 5. AppViewModel Error & Diagnostic Integration

    func testAppViewModelToastLifecycle() {
        let vm = AppViewModel(repository: DiagnosticMockRepo(), cliService: DiagnosticMockCLI())
        XCTAssertNil(vm.activeToast)

        vm.showToast(title: "Success", message: "Saved perfectly", isError: false)
        XCTAssertNotNil(vm.activeToast)
        XCTAssertEqual(vm.activeToast?.title, "Success")
        XCTAssertEqual(vm.activeToast?.message, "Saved perfectly")
        XCTAssertFalse(vm.activeToast?.isError ?? true)

        vm.dismissToast()
        XCTAssertNil(vm.activeToast)

        vm.showToast(title: "Error", message: "Something failed", isError: true)
        XCTAssertNotNil(vm.activeToast)
        XCTAssertTrue(vm.activeToast?.isError ?? false)
    }

    func testAppViewModelDiagnosticLifecycle() {
        let vm = AppViewModel(repository: DiagnosticMockRepo(), cliService: DiagnosticMockCLI())
        XCTAssertNil(vm.activeDiagnostic)

        let report = AppDiagnosticReport(
            title: "Manual Diagnostic",
            summary: "Summary text",
            rootCause: "Cause text",
            recoverySuggestion: "Action text",
            domain: .cli,
            technicalDetails: "Details"
        )

        vm.showDiagnostic(report)
        XCTAssertNotNil(vm.activeDiagnostic)
        XCTAssertEqual(vm.activeDiagnostic?.title, "Manual Diagnostic")

        vm.dismissDiagnostic()
        XCTAssertNil(vm.activeDiagnostic)
    }

    func testAppViewModelSaveFailureTriggersDiagnosticAndToast() async {
        let failRepo = DiagnosticMockRepo(shouldFailSaveWith: .backupFailed(
            targetURL: URL(fileURLWithPath: "/Users/test/config"),
            underlyingError: "Application Support directory locked"
        ))
        let vm = AppViewModel(repository: failRepo, cliService: DiagnosticMockCLI())

        let success = await vm.saveConfiguration()
        XCTAssertFalse(success)

        // Diagnostic report generated
        XCTAssertNotNil(vm.activeDiagnostic)
        XCTAssertEqual(vm.activeDiagnostic?.domain, .backup)
        XCTAssertEqual(vm.activeDiagnostic?.title, "Safety Backup Creation Failed")

        // Toast notification shown
        XCTAssertNotNil(vm.activeToast)
        XCTAssertTrue(vm.activeToast?.isError ?? false)
        XCTAssertEqual(vm.activeToast?.title, "Save Failed")
    }

    func testAppViewModelRestoreBackupFailureTriggersDiagnosticAndToast() async {
        let failRepo = DiagnosticMockRepo(shouldFailRestoreWith: GhosttyConfigRepositoryError.cannotReadFile(
            url: URL(fileURLWithPath: "/backups/b1.ghostty"),
            underlyingError: "Corrupt file"
        ))
        let vm = AppViewModel(repository: failRepo, cliService: DiagnosticMockCLI())
        let backup = GhosttyBackupInfo(
            url: URL(fileURLWithPath: "/backups/b1.ghostty"),
            fileName: "b1.ghostty",
            creationDate: Date(),
            sizeInBytes: 256
        )

        let success = await vm.restoreBackup(backup)
        XCTAssertFalse(success)

        XCTAssertNotNil(vm.activeDiagnostic)
        XCTAssertEqual(vm.activeDiagnostic?.domain, .filesystem)
        XCTAssertEqual(vm.activeDiagnostic?.title, "Cannot Read Configuration File")

        XCTAssertNotNil(vm.activeToast)
        XCTAssertTrue(vm.activeToast?.isError ?? false)
        XCTAssertEqual(vm.activeToast?.title, "Restore Failed")
    }

    func testAppViewModelValidationFailureTriggersDiagnostic() async {
        let mockCLI = DiagnosticMockCLI(validationResult: GhosttyValidationResult(
            isValid: false,
            issues: [GhosttyValidationIssue(line: 4, message: "bad option")],
            rawOutput: "error: bad option"
        ))
        let vm = AppViewModel(repository: DiagnosticMockRepo(), cliService: mockCLI)
        await vm.checkCLIStatus()

        let result = await vm.validateCurrentDocument()
        XCTAssertNotNil(result)
        XCTAssertFalse(result?.isValid ?? true)

        XCTAssertNotNil(vm.activeDiagnostic)
        XCTAssertEqual(vm.activeDiagnostic?.domain, DiagnosticDomain.validation)
        XCTAssertEqual(vm.activeDiagnostic?.title, "Ghostty CLI Validation Failed")
    }

    func testAppViewModelValidationSkippedWhenCLINotAvailable() async {
        let mockCLI = DiagnosticMockCLI(isInstalled: false)
        let vm = AppViewModel(repository: DiagnosticMockRepo(), cliService: mockCLI)
        await vm.checkCLIStatus()

        let result = await vm.validateCurrentDocument()
        XCTAssertNil(result)
        if case .skipped = vm.validationState {
            // Success
        } else {
            XCTFail("Expected .skipped validation state")
        }
    }

    // MARK: - 6. UI Components Hook Tests

    func testFloatingToastViewInspectionHook() {
        var inspected = false
        var dismissed = false

        let errorToast = AppViewModel.ToastNotification(
            title: "Validation Failed",
            message: "Check your settings.",
            isError: true
        )

        let toastView = FloatingToastView(
            toast: errorToast,
            onDismiss: { dismissed = true },
            onInspect: { inspected = true }
        )

        XCTAssertNotNil(toastView.body)
        toastView.onDismiss()
        XCTAssertTrue(dismissed)

        toastView.onInspect?()
        XCTAssertTrue(inspected)
    }

    func testDiagnosticSheetViewInstantiates() {
        let report = AppDiagnosticReport(
            title: "CLI Missing",
            summary: "Ghostty CLI was not found.",
            rootCause: "Not installed in /Applications.",
            recoverySuggestion: "Install Ghostty from website.",
            domain: .cli,
            technicalDetails: "/Applications/Ghostty.app missing",
            actions: [
                DiagnosticAction(title: "Revert", systemImage: "arrow.uturn.backward", kind: .revertChanges, isDestructive: true),
                DiagnosticAction(title: "Dismiss", systemImage: "xmark", kind: .dismiss)
            ]
        )

        var isPresented = true
        let binding = Binding<Bool>(
            get: { isPresented },
            set: { isPresented = $0 }
        )

        let sheetView = DiagnosticSheetView(report: report, isPresented: binding)
        XCTAssertNotNil(sheetView.body)
    }
}

// MARK: - Test Mocks

private final class DiagnosticMockRepo: GhosttyConfigRepositoryProtocol, @unchecked Sendable {
    var pathResolver: GhosttyConfigPathResolver = GhosttyConfigPathResolver()
    var effectivePath: GhosttyConfigPath?
    var shouldFailSaveWith: GhosttyConfigRepositoryError?
    var shouldFailRestoreWith: Error?

    init(
        effectivePath: GhosttyConfigPath? = nil,
        shouldFailSaveWith: GhosttyConfigRepositoryError? = nil,
        shouldFailRestoreWith: Error? = nil
    ) {
        self.effectivePath = effectivePath ?? GhosttyConfigPath(
            url: URL(fileURLWithPath: "/mock/config.ghostty"),
            scope: .macOS,
            exists: true,
            precedenceOrder: 4
        )
        self.shouldFailSaveWith = shouldFailSaveWith
        self.shouldFailRestoreWith = shouldFailRestoreWith
    }

    func discoverEffectivePath() -> GhosttyConfigPath? { effectivePath }
    func loadEffectiveConfiguration() throws -> LoadedConfiguration? {
        LoadedConfiguration(
            path: effectivePath!,
            document: GhosttyConfigDocument(),
            rawContent: ""
        )
    }
    func readConfiguration(at url: URL) throws -> LoadedConfiguration {
        LoadedConfiguration(
            path: effectivePath!,
            document: GhosttyConfigDocument(),
            rawContent: ""
        )
    }

    func saveConfiguration(
        document: GhosttyConfigDocument,
        to targetURL: URL?,
        createBackup: Bool,
        validate: Bool
    ) throws -> SaveResult {
        if let err = shouldFailSaveWith {
            throw err
        }
        return SaveResult(
            targetURL: targetURL ?? effectivePath!.url,
            backupURL: nil,
            validationResult: .valid,
            document: document
        )
    }

    func createBackup(for sourceURL: URL) throws -> GhosttyBackupInfo {
        GhosttyBackupInfo(url: sourceURL, fileName: "b.ghostty", creationDate: Date(), sizeInBytes: 10)
    }

    func listBackups() throws -> [GhosttyBackupInfo] { [] }

    func deleteBackup(at backupURL: URL) throws {}

    func pruneBackups(keepLatest count: Int) throws -> Int { 0 }

    func restoreBackup(from backupURL: URL, to targetURL: URL?, validate: Bool) throws -> SaveResult {
        if let err = shouldFailRestoreWith {
            throw err
        }
        return SaveResult(
            targetURL: targetURL ?? effectivePath!.url,
            backupURL: nil,
            validationResult: .valid,
            document: GhosttyConfigDocument()
        )
    }
}

private final class DiagnosticMockCLI: GhosttyCLIServiceProtocol, @unchecked Sendable {
    var isInstalled: Bool
    var validationResult: GhosttyValidationResult

    init(isInstalled: Bool = true, validationResult: GhosttyValidationResult = .valid) {
        self.isInstalled = isInstalled
        self.validationResult = validationResult
    }

    func isGhosttyInstalled() -> Bool { isInstalled }
    func executableURL() throws -> URL { URL(fileURLWithPath: "/usr/bin/ghostty") }
    func validateConfig(at fileURL: URL) throws -> GhosttyValidationResult { validationResult }
    func listFonts() throws -> [GhosttyFontFamily] { [] }
    func listThemes(colorScheme: GhosttyThemeColorScheme) throws -> [GhosttyTheme] { [] }
    func getDefaultConfigDocument() throws -> GhosttyConfigDocument { GhosttyConfigDocument() }
    func getVersion() throws -> String { "Ghostty 1.3.1" }
}
