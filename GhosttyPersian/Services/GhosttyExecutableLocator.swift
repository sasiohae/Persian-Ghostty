import Foundation

/// Service responsible for locating the Ghostty executable on macOS.
public struct GhosttyExecutableLocator: Sendable {
    /// Optional user-specified custom path to the Ghostty executable.
    public let customPath: URL?

    /// Environment variables to inspect (e.g. PATH, HOME).
    public let environment: [String: String]

    /// Predicate to check if a file exists and is executable at a given filesystem path.
    public let isExecutableFile: @Sendable (String) -> Bool

    public init(
        customPath: URL? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isExecutableFile: @escaping @Sendable (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) {
        self.customPath = customPath
        self.environment = environment
        self.isExecutableFile = isExecutableFile
    }

    /// Ordered candidate file paths to search for the Ghostty binary.
    public func candidatePaths() -> [String] {
        var paths: [String] = []

        // 1. Explicit custom path override
        if let custom = customPath {
            paths.append(custom.path)
        }

        // 2. Primary macOS Application bundle
        paths.append("/Applications/Ghostty.app/Contents/MacOS/ghostty")

        // 3. User Applications bundle (~/Applications)
        let home = environment["HOME"] ?? ("~" as NSString).expandingTildeInPath
        paths.append("\(home)/Applications/Ghostty.app/Contents/MacOS/ghostty")

        // 4. Common Homebrew and Unix binary locations
        paths.append("/opt/homebrew/bin/ghostty")
        paths.append("/usr/local/bin/ghostty")

        // 5. System PATH directories
        if let pathEnv = environment["PATH"] {
            let directories = pathEnv.split(separator: ":").map(String.init)
            for dir in directories {
                let candidate = (dir as NSString).appendingPathComponent("ghostty")
                if !paths.contains(candidate) {
                    paths.append(candidate)
                }
            }
        }

        return paths
    }

    /// Discovers the first existing executable path for Ghostty.
    public func findExecutable() -> URL? {
        for path in candidatePaths() {
            if isExecutableFile(path) {
                return URL(fileURLWithPath: path)
            }
        }
        return nil
    }

    /// Checks if a valid Ghostty executable is available on the system.
    public func isGhosttyInstalled() -> Bool {
        findExecutable() != nil
    }
}
