import AppKit

/// Protocol abstracting macOS workspace and file opening interactions for testability.
public protocol WorkspaceOpening: Sendable {
    /// Opens the specified URL with its default application.
    @MainActor func open(_ url: URL) -> Bool

    /// Activates Finder and selects the specified file URLs.
    @MainActor func activateFileViewerSelecting(_ fileURLs: [URL])
}

/// Default implementation delegating to `NSWorkspace.shared`.
public struct DefaultWorkspaceOpener: WorkspaceOpening {
    public init() {}

    @MainActor
    public func open(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }

    @MainActor
    public func activateFileViewerSelecting(_ fileURLs: [URL]) {
        NSWorkspace.shared.activateFileViewerSelecting(fileURLs)
    }
}

/// Mock implementation for unit tests.
public final class MockWorkspaceOpener: WorkspaceOpening, @unchecked Sendable {
    public var openedURLs: [URL] = []
    public var revealedURLs: [[URL]] = []

    public init() {}

    @MainActor
    public func open(_ url: URL) -> Bool {
        openedURLs.append(url)
        return true
    }

    @MainActor
    public func activateFileViewerSelecting(_ fileURLs: [URL]) {
        revealedURLs.append(fileURLs)
    }
}
