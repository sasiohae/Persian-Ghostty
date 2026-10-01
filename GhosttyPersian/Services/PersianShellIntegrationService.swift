import Foundation

/// Protocol governing interactive Persian shell integration and BiDi helpers.
public protocol PersianShellIntegrationServicing: Sendable {
    var homeDirectory: URL { get }
    var environment: [String: String] { get }

    /// Detects the active shell (e.g. zsh or fish) from environment and system configuration.
    func detectActiveShell() -> PersianShellType

    /// Resolves the configuration target URL for a given shell type.
    func configurationURL(for shell: PersianShellType) -> URL

    /// Generates the safe, non-destructive script content for a given shell type.
    func generateHookScript(for shell: PersianShellType) -> String

    /// Checks if the integration is currently installed for a given shell type.
    func isInstalled(for shell: PersianShellType) -> Bool

    /// Checks if fribidi or a BiDi helper is available on the system.
    func checkBiDiHelperAvailability() -> (isAvailable: Bool, path: String?)

    /// Returns a comprehensive status report for a given shell type.
    func getStatus(for shell: PersianShellType) -> PersianShellStatus

    /// Safely installs the Persian shell integration for the specified shell.
    @discardableResult
    func install(for shell: PersianShellType) throws -> URL

    /// Safely removes the Persian shell integration for the specified shell.
    @discardableResult
    func remove(for shell: PersianShellType) throws -> Bool
}

/// Service implementing safe, non-destructive interactive helpers for Persian RTL/BiDi handling.
public struct PersianShellIntegrationService: PersianShellIntegrationServicing, @unchecked Sendable {
    public let homeDirectory: URL
    public let environment: [String: String]
    public let fileManager: FileManager
    public let isExecutableFile: @Sendable (String) -> Bool

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default,
        isExecutableFile: @escaping @Sendable (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) {
        self.homeDirectory = homeDirectory
        self.environment = environment
        self.fileManager = fileManager
        self.isExecutableFile = isExecutableFile
    }

    // MARK: - Shell Detection

    /// Detects active shell based on the $SHELL environment variable.
    public func detectActiveShell() -> PersianShellType {
        if let shellEnv = environment["SHELL"]?.lowercased() {
            if shellEnv.contains("fish") {
                return .fish
            }
            if shellEnv.contains("zsh") {
                return .zsh
            }
        }

        // Check if fish configuration exists in user directory
        let fishConfigDir = homeDirectory
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("fish", isDirectory: true)
        if fileManager.fileExists(atPath: fishConfigDir.path) && !fileManager.fileExists(atPath: homeDirectory.appendingPathComponent(".zshrc").path) {
            return .fish
        }

        // macOS standard default since Catalina
        return .zsh
    }

    // MARK: - Path Resolution

    public func configurationURL(for shell: PersianShellType) -> URL {
        switch shell {
        case .zsh:
            return homeDirectory.appendingPathComponent(".zshrc", isDirectory: false)
        case .fish:
            return homeDirectory
                .appendingPathComponent(".config", isDirectory: true)
                .appendingPathComponent("fish", isDirectory: true)
                .appendingPathComponent("conf.d", isDirectory: true)
                .appendingPathComponent("ghostty_persian.fish", isDirectory: false)
        }
    }

    // MARK: - Hook Generation

    public func generateHookScript(for shell: PersianShellType) -> String {
        switch shell {
        case .zsh:
            return """
            \(PersianShellMarkers.startMarker)
            # Persian RTL & BiDi interactive helpers for Ghostty
            export LC_CTYPE="${LC_CTYPE:-UTF-8}"
            setopt COMBINING_CHARS 2>/dev/null || true

            if command -v fribidi >/dev/null 2>&1; then
                alias bidi="fribidi --charset UTF-8"
                alias pcat="fribidi --charset UTF-8"
                pecho() { echo "$*" | fribidi --charset UTF-8; }
            else
                alias bidi="cat"
                alias pcat="cat"
                pecho() { echo "$*"; }
            fi

            # On-the-fly RTL line reversal widget (Option + R)
            fix_persian_line() {
                if command -v fribidi >/dev/null 2>&1; then
                    BUFFER=$(echo "$BUFFER" | fribidi)
                    CURSOR=$#BUFFER
                fi
            }
            zle -N fix_persian_line 2>/dev/null || true
            bindkey '\\er' fix_persian_line 2>/dev/null || true
            bindkey '^[r' fix_persian_line 2>/dev/null || true
            \(PersianShellMarkers.endMarker)
            """

        case .fish:
            return """
            \(PersianShellMarkers.startMarker)
            # Persian RTL & BiDi interactive helpers for Ghostty (Fish)
            set -q LC_CTYPE; or set -gx LC_CTYPE "UTF-8"

            if type -q fribidi
                alias bidi="fribidi --charset UTF-8"
                alias pcat="fribidi --charset UTF-8"
                function pecho
                    echo $argv | fribidi --charset UTF-8
                end
            else
                alias bidi="cat"
                alias pcat="cat"
                function pecho
                    echo $argv
                end
            end

            # On-the-fly RTL line reversal function (Option + R)
            function fix_persian_line
                set -l current_line (commandline)
                set -l fixed_line (echo $current_line | fribidi)
                commandline -r $fixed_line
            end
            bind \\er fix_persian_line
            \(PersianShellMarkers.endMarker)
            """
        }
    }

    // MARK: - Status & Inspection

    public func isInstalled(for shell: PersianShellType) -> Bool {
        let url = configurationURL(for: shell)
        guard fileManager.fileExists(atPath: url.path) else {
            // Also check fish config.fish fallback if conf.d drop-in is not present
            if shell == .fish {
                let mainFishConfig = homeDirectory
                    .appendingPathComponent(".config", isDirectory: true)
                    .appendingPathComponent("fish", isDirectory: true)
                    .appendingPathComponent("config.fish", isDirectory: false)
                if let content = try? String(contentsOf: mainFishConfig, encoding: .utf8) {
                    return content.contains(PersianShellMarkers.startMarker) && content.contains(PersianShellMarkers.endMarker)
                }
            }
            return false
        }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return false
        }

        return content.contains(PersianShellMarkers.startMarker) && content.contains(PersianShellMarkers.endMarker)
    }

    public func checkBiDiHelperAvailability() -> (isAvailable: Bool, path: String?) {
        var candidates: [String] = [
            "/opt/homebrew/bin/fribidi",
            "/usr/local/bin/fribidi",
            "/usr/bin/fribidi"
        ]

        if let pathEnv = environment["PATH"] {
            for dir in pathEnv.split(separator: ":").map(String.init) {
                let candidate = (dir as NSString).appendingPathComponent("fribidi")
                if !candidates.contains(candidate) {
                    candidates.append(candidate)
                }
            }
        }

        for path in candidates {
            if isExecutableFile(path) {
                return (true, path)
            }
        }

        return (false, nil)
    }

    public func getStatus(for shell: PersianShellType) -> PersianShellStatus {
        let installed = isInstalled(for: shell)
        let configURL = configurationURL(for: shell)
        let bidi = checkBiDiHelperAvailability()

        return PersianShellStatus(
            shell: shell,
            isInstalled: installed,
            configURL: configURL,
            isBiDiHelperAvailable: bidi.isAvailable,
            biDiHelperPath: bidi.path,
            lastCheckedDate: Date()
        )
    }

    // MARK: - Safe Installation

    @discardableResult
    public func install(for shell: PersianShellType) throws -> URL {
        let targetURL = configurationURL(for: shell)
        let parentDir = targetURL.deletingLastPathComponent()

        // 1. Ensure directory exists
        if !fileManager.fileExists(atPath: parentDir.path) {
            do {
                try fileManager.createDirectory(at: parentDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                throw PersianShellIntegrationError.directoryCreationFailed(url: parentDir, underlyingError: error.localizedDescription)
            }
        }

        let script = generateHookScript(for: shell)

        switch shell {
        case .zsh:
            try installZshIntegration(targetURL: targetURL, script: script)

        case .fish:
            try installFishIntegration(targetURL: targetURL, script: script)
        }

        return targetURL
    }

    private func installZshIntegration(targetURL: URL, script: String) throws {
        if fileManager.fileExists(atPath: targetURL.path) {
            let existingContent: String
            do {
                existingContent = try String(contentsOf: targetURL, encoding: .utf8)
            } catch {
                throw PersianShellIntegrationError.fileReadFailed(url: targetURL, underlyingError: error.localizedDescription)
            }

            let newContent: String
            if let startRange = existingContent.range(of: PersianShellMarkers.startMarker),
               let endRange = existingContent.range(of: PersianShellMarkers.endMarker),
               startRange.lowerBound <= endRange.upperBound {
                // Replace existing integration block cleanly
                var modified = existingContent
                modified.replaceSubrange(startRange.lowerBound..<endRange.upperBound, with: script)
                newContent = modified
            } else {
                // Append cleanly to existing file
                let separator = existingContent.hasSuffix("\n") ? "\n" : "\n\n"
                newContent = existingContent + separator + script + "\n"
            }

            do {
                try newContent.write(to: targetURL, atomically: true, encoding: .utf8)
            } catch {
                throw PersianShellIntegrationError.fileWriteFailed(url: targetURL, underlyingError: error.localizedDescription)
            }
        } else {
            // Create fresh file
            let content = script + "\n"
            do {
                try content.write(to: targetURL, atomically: true, encoding: .utf8)
            } catch {
                throw PersianShellIntegrationError.fileWriteFailed(url: targetURL, underlyingError: error.localizedDescription)
            }
        }
    }

    private func installFishIntegration(targetURL: URL, script: String) throws {
        let content = script + "\n"
        do {
            try content.write(to: targetURL, atomically: true, encoding: .utf8)
        } catch {
            throw PersianShellIntegrationError.fileWriteFailed(url: targetURL, underlyingError: error.localizedDescription)
        }
    }

    // MARK: - Safe Removal

    @discardableResult
    public func remove(for shell: PersianShellType) throws -> Bool {
        switch shell {
        case .zsh:
            return try removeZshIntegration()
        case .fish:
            return try removeFishIntegration()
        }
    }

    private func removeZshIntegration() throws -> Bool {
        let targetURL = configurationURL(for: .zsh)
        guard fileManager.fileExists(atPath: targetURL.path) else {
            return true
        }

        let existingContent: String
        do {
            existingContent = try String(contentsOf: targetURL, encoding: .utf8)
        } catch {
            throw PersianShellIntegrationError.fileReadFailed(url: targetURL, underlyingError: error.localizedDescription)
        }

        guard let startRange = existingContent.range(of: PersianShellMarkers.startMarker),
              let endRange = existingContent.range(of: PersianShellMarkers.endMarker),
              startRange.lowerBound <= endRange.upperBound else {
            return true // Not installed, safe no-op
        }

        // Expand deletion to consume trailing newline if present
        var deleteEnd = endRange.upperBound
        if deleteEnd < existingContent.endIndex && existingContent[deleteEnd] == "\n" {
            deleteEnd = existingContent.index(after: deleteEnd)
        }

        // Also consume preceding newline if at line start
        var deleteStart = startRange.lowerBound
        if deleteStart > existingContent.startIndex {
            let beforeStart = existingContent.index(before: deleteStart)
            if existingContent[beforeStart] == "\n" {
                deleteStart = beforeStart
            }
        }

        var cleaned = existingContent
        cleaned.removeSubrange(deleteStart..<deleteEnd)

        // Clean up any double blank lines at end
        while cleaned.hasSuffix("\n\n\n") {
            cleaned.removeLast()
        }

        do {
            try cleaned.write(to: targetURL, atomically: true, encoding: .utf8)
            return true
        } catch {
            throw PersianShellIntegrationError.fileWriteFailed(url: targetURL, underlyingError: error.localizedDescription)
        }
    }

    private func removeFishIntegration() throws -> Bool {
        let dropInURL = configurationURL(for: .fish)
        var removedAny = false

        if fileManager.fileExists(atPath: dropInURL.path) {
            do {
                try fileManager.removeItem(at: dropInURL)
                removedAny = true
            } catch {
                throw PersianShellIntegrationError.removalFailed(url: dropInURL, underlyingError: error.localizedDescription)
            }
        }

        // Also clean up main config.fish if it contained markers
        let mainFishConfig = homeDirectory
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("fish", isDirectory: true)
            .appendingPathComponent("config.fish", isDirectory: false)

        if fileManager.fileExists(atPath: mainFishConfig.path),
           let content = try? String(contentsOf: mainFishConfig, encoding: .utf8),
           let startRange = content.range(of: PersianShellMarkers.startMarker),
           let endRange = content.range(of: PersianShellMarkers.endMarker),
           startRange.lowerBound <= endRange.upperBound {
            var modified = content
            modified.removeSubrange(startRange.lowerBound...content.index(before: endRange.upperBound))
            try? modified.write(to: mainFishConfig, atomically: true, encoding: .utf8)
            removedAny = true
        }

        return removedAny || !fileManager.fileExists(atPath: dropInURL.path)
    }
}
