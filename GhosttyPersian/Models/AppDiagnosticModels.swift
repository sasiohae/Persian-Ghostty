import Foundation

/// Problem domains for errors occurring within the application.
public enum DiagnosticDomain: String, Sendable, CaseIterable, Identifiable, Equatable {
    case cli = "Ghostty CLI"
    case validation = "Validation"
    case filesystem = "File System"
    case permissions = "Permissions"
    case backup = "Backup & Recovery"
    case general = "General"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .cli: return "terminal"
        case .validation: return "exclamationmark.shield"
        case .filesystem: return "folder.badge.gearshape"
        case .permissions: return "lock.trianglebadge.exclamationmark"
        case .backup: return "clock.arrow.circlepath"
        case .general: return "exclamationmark.circle"
        }
    }
}

/// Actionable recovery choices presented to the user inside error diagnostics.
public enum DiagnosticActionKind: Sendable, Equatable {
    case restoreLastBackup
    case revertChanges
    case revealInFinder(URL)
    case runValidation
    case copyDiagnostics
    case dismiss
}

/// An interactive recovery action.
public struct DiagnosticAction: Identifiable, Sendable, Equatable {
    public var id: String { title }
    public let title: String
    public let systemImage: String
    public let kind: DiagnosticActionKind
    public let isDestructive: Bool

    public init(
        title: String,
        systemImage: String,
        kind: DiagnosticActionKind,
        isDestructive: Bool = false
    ) {
        self.title = title
        self.systemImage = systemImage
        self.kind = kind
        self.isDestructive = isDestructive
    }
}

/// Unified diagnostic report presenting human-readable summaries and technical details.
public struct AppDiagnosticReport: Identifiable, Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let summary: String
    public let rootCause: String
    public let recoverySuggestion: String
    public let domain: DiagnosticDomain
    public let technicalDetails: String
    public let actions: [DiagnosticAction]
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        rootCause: String,
        recoverySuggestion: String,
        domain: DiagnosticDomain,
        technicalDetails: String,
        actions: [DiagnosticAction] = [],
        timestamp: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.rootCause = rootCause
        self.recoverySuggestion = recoverySuggestion
        self.domain = domain
        self.technicalDetails = technicalDetails
        self.actions = actions
        self.timestamp = timestamp
    }

    /// Generates a standardized textual diagnostic report for clipboard copying.
    public var formattedReportForClipboard: String {
        """
        --- GHOSTTY PERSIAN DIAGNOSTIC REPORT ---
        Timestamp: \(timestamp)
        Domain: \(domain.rawValue)
        Title: \(title)

        Summary:
        \(summary)

        Root Cause:
        \(rootCause)

        Suggested Action:
        \(recoverySuggestion)

        Technical Details / Logs:
        \(technicalDetails)
        -----------------------------------------
        """
    }
}
