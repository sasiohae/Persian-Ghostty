import Foundation

/// Service for analyzing errors and generating actionable diagnostic reports.
public struct DiagnosticService: Sendable {
    public init() {}

    /// Transforms any error into a user-friendly, structured diagnostic report.
    public static func createReport(from error: Error, targetURL: URL? = nil) -> AppDiagnosticReport {
        if let repoError = error as? GhosttyConfigRepositoryError {
            return report(for: repoError, targetURL: targetURL)
        }

        if let cliError = error as? GhosttyCLIError {
            return report(for: cliError)
        }

        let nsError = error as NSError
        let isPermission = nsError.domain == NSCocoaErrorDomain && (nsError.code == NSFileWriteNoPermissionError || nsError.code == NSFileReadNoPermissionError)
            || nsError.domain == NSPOSIXErrorDomain && nsError.code == 13

        let domain: DiagnosticDomain = isPermission ? .permissions : .general
        let title = isPermission ? "Permission Denied" : "Unexpected Operation Error"
        let recovery = isPermission
            ? "Ensure your macOS user account has read/write permissions for the target folder and file."
            : "Review technical logs or restart Ghostty Persian."

        var actions: [DiagnosticAction] = []
        if let url = targetURL {
            actions.append(DiagnosticAction(title: "Reveal in Finder", systemImage: "folder", kind: .revealInFinder(url)))
        }
        actions.append(DiagnosticAction(title: "Revert Unsaved Changes", systemImage: "arrow.uturn.backward", kind: .revertChanges, isDestructive: true))

        return AppDiagnosticReport(
            title: title,
            summary: error.localizedDescription,
            rootCause: nsError.localizedFailureReason ?? "System error code \(nsError.code) in domain '\(nsError.domain)'",
            recoverySuggestion: recovery,
            domain: domain,
            technicalDetails: "\(error)",
            actions: actions
        )
    }

    // MARK: - Specialized Mappers

    private static func report(for error: GhosttyConfigRepositoryError, targetURL: URL?) -> AppDiagnosticReport {
        switch error {
        case .validationFailed(let issues, let rawOutput):
            var actions: [DiagnosticAction] = [
                DiagnosticAction(title: "Revert Unsaved Changes", systemImage: "arrow.uturn.backward", kind: .revertChanges, isDestructive: true),
                DiagnosticAction(title: "Restore from Last Backup", systemImage: "clock.arrow.circlepath", kind: .restoreLastBackup)
            ]
            if let url = targetURL {
                actions.append(DiagnosticAction(title: "Reveal in Finder", systemImage: "folder", kind: .revealInFinder(url)))
            }

            let issueSummary = issues.isEmpty
                ? "Ghostty configuration validation reported errors."
                : issues.map { "• Line \($0.line ?? 0): \($0.message)" }.joined(separator: "\n")

            return AppDiagnosticReport(
                title: "Ghostty CLI Validation Failed",
                summary: "Ghostty rejected the proposed configuration during safety validation.",
                rootCause: "The staging file contains syntax errors or unrecognized values that Ghostty cannot load. The active configuration file on disk was left 100% untouched.",
                recoverySuggestion: "Inspect the reported invalid lines below, revert problematic settings, or restore from a known-good backup snapshot.",
                domain: .validation,
                technicalDetails: rawOutput.isEmpty ? issueSummary : "\(rawOutput)\n\nIssues:\n\(issueSummary)",
                actions: actions
            )

        case .atomicReplacementFailed(let url, let underlying):
            let isPerm = underlying.localizedCaseInsensitiveContains("permission") || underlying.localizedCaseInsensitiveContains("denied")
            let domain: DiagnosticDomain = isPerm ? .permissions : .filesystem
            let title = isPerm ? "Permission Denied Replacing Configuration" : "Configuration Replacement Failed"

            let actions: [DiagnosticAction] = [
                DiagnosticAction(title: "Reveal in Finder", systemImage: "folder", kind: .revealInFinder(url)),
                DiagnosticAction(title: "Revert Unsaved Changes", systemImage: "arrow.uturn.backward", kind: .revertChanges, isDestructive: true)
            ]

            return AppDiagnosticReport(
                title: title,
                summary: "Could not safely replace the configuration file at '\(url.path)'.",
                rootCause: underlying,
                recoverySuggestion: isPerm
                    ? "Check permissions for '\(url.deletingLastPathComponent().path)' and ensure your account has write access."
                    : "Check if the file is locked by another application or if the disk has sufficient space.",
                domain: domain,
                technicalDetails: "Target Path: \(url.path)\nError: \(underlying)",
                actions: actions
            )

        case .backupFailed(let targetURL, let underlying):
            return AppDiagnosticReport(
                title: "Safety Backup Creation Failed",
                summary: "Failed to create a pre-write backup for '\(targetURL.lastPathComponent)'.",
                rootCause: underlying,
                recoverySuggestion: "The save operation was aborted before modifying your configuration file to guarantee zero data loss. Verify that the Application Support directory is writable.",
                domain: .backup,
                technicalDetails: "Target Path: \(targetURL.path)\nUnderlying: \(underlying)",
                actions: [
                    DiagnosticAction(title: "Reveal Target in Finder", systemImage: "folder", kind: .revealInFinder(targetURL)),
                    DiagnosticAction(title: "Revert Changes", systemImage: "arrow.uturn.backward", kind: .revertChanges, isDestructive: true)
                ]
            )

        case .stagingWriteFailed(let url, let underlying):
            return AppDiagnosticReport(
                title: "Staging File Creation Failed",
                summary: "Could not write temporary staging configuration.",
                rootCause: underlying,
                recoverySuggestion: "Ensure the temporary directory is accessible and free disk space is available.",
                domain: .filesystem,
                technicalDetails: "Staging Path: \(url.path)\nError: \(underlying)",
                actions: [
                    DiagnosticAction(title: "Revert Changes", systemImage: "arrow.uturn.backward", kind: .revertChanges, isDestructive: true)
                ]
            )

        case .cannotReadFile(let url, let underlying):
            return AppDiagnosticReport(
                title: "Cannot Read Configuration File",
                summary: "Failed to read configuration at '\(url.lastPathComponent)'.",
                rootCause: underlying,
                recoverySuggestion: "Check if the file was deleted, moved, or has restricted read permissions.",
                domain: .filesystem,
                technicalDetails: "Path: \(url.path)\nError: \(underlying)",
                actions: [
                    DiagnosticAction(title: "Reveal in Finder", systemImage: "folder", kind: .revealInFinder(url))
                ]
            )

        case .directoryCreationFailed(let url, let underlying):
            return AppDiagnosticReport(
                title: "Directory Creation Failed",
                summary: "Could not create directory at '\(url.path)'.",
                rootCause: underlying,
                recoverySuggestion: "Check folder permissions and parent directory access.",
                domain: .filesystem,
                technicalDetails: "Directory: \(url.path)\nError: \(underlying)",
                actions: [
                    DiagnosticAction(title: "Reveal in Finder", systemImage: "folder", kind: .revealInFinder(url))
                ]
            )

        case .configurationNotFound(let paths):
            return AppDiagnosticReport(
                title: "Configuration File Not Found",
                summary: "No Ghostty configuration file currently exists on disk.",
                rootCause: "Searched default macOS and XDG directories: \(paths.joined(separator: ", ")).",
                recoverySuggestion: "Save your desired settings in Ghostty Persian to automatically create a new configuration file at the recommended location.",
                domain: .filesystem,
                technicalDetails: "Searched Paths:\n" + paths.map { "- \($0)" }.joined(separator: "\n"),
                actions: []
            )
        }
    }

    private static func report(for error: GhosttyCLIError) -> AppDiagnosticReport {
        switch error {
        case .executableNotFound(let paths):
            return AppDiagnosticReport(
                title: "Ghostty CLI Not Found",
                summary: "Ghostty terminal executable was not detected on this machine.",
                rootCause: "Searched standard macOS locations:\n" + paths.map { "- \($0)" }.joined(separator: "\n"),
                recoverySuggestion: "Install Ghostty from https://ghostty.org or ensure Ghostty.app is installed in /Applications.",
                domain: .cli,
                technicalDetails: "Searched candidate paths:\n\(paths.joined(separator: "\n"))",
                actions: []
            )

        case .executionFailed(let command, let exitCode, let stderr):
            return AppDiagnosticReport(
                title: "Ghostty CLI Execution Failed",
                summary: "Ghostty command returned error code \(exitCode).",
                rootCause: stderr.trimmingCharacters(in: .whitespacesAndNewlines),
                recoverySuggestion: "Check command arguments or inspect technical error output below.",
                domain: .cli,
                technicalDetails: "Command: \(command)\nExit Code: \(exitCode)\nStderr:\n\(stderr)",
                actions: []
            )

        case .processTimeout(let command, let timeout):
            return AppDiagnosticReport(
                title: "CLI Command Timed Out",
                summary: "Ghostty CLI process exceeded the \(timeout)s deadline.",
                rootCause: "Command '\(command)' did not finish within the allowed time limit.",
                recoverySuggestion: "Ghostty may be hanging or awaiting user input. Try running the command again.",
                domain: .cli,
                technicalDetails: "Command: \(command)\nTimeout: \(timeout)s",
                actions: []
            )

        case .invalidOutput(let command, let details):
            return AppDiagnosticReport(
                title: "Unexpected CLI Output",
                summary: "Ghostty returned output in an unrecognized format.",
                rootCause: details,
                recoverySuggestion: "Ensure you are using a compatible version of Ghostty (1.0.0 or later).",
                domain: .cli,
                technicalDetails: "Command: \(command)\nDetails: \(details)",
                actions: []
            )
        }
    }
}
