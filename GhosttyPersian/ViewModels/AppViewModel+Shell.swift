import Foundation

extension AppViewModel {
    // MARK: - Shell Settings

    /// Custom shell command or binary to execute for new terminal surfaces (Ghostty `command`).
    ///
    /// If empty, Ghostty automatically looks up `$SHELL` or the system user database.
    public var shellCommand: String {
        get {
            currentDocument.effectiveValue(for: "command") ?? ""
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                removeSetting(key: "command")
            } else {
                updateSetting(key: "command", value: trimmed)
            }
        }
    }

    /// Shell integration auto-injection mode (Ghostty `shell-integration`).
    public var shellIntegration: GhosttyShellIntegrationMode {
        get {
            if let val = currentDocument.effectiveValue(for: "shell-integration"),
               let mode = GhosttyShellIntegrationMode(rawValue: val) {
                return mode
            }
            return .detect
        }
        set {
            updateSetting(key: "shell-integration", value: newValue.rawValue)
        }
    }

    /// Raw comma-separated string for `shell-integration-features`.
    public var shellIntegrationFeaturesRaw: String {
        get {
            currentDocument.effectiveValue(for: "shell-integration-features") ?? "cursor,no-sudo,title,no-ssh-env,no-ssh-terminfo,path"
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                removeSetting(key: "shell-integration-features")
            } else {
                updateSetting(key: "shell-integration-features", value: trimmed)
            }
        }
    }

    /// Checks whether an individual shell integration feature is active.
    public func isShellFeatureEnabled(_ feature: GhosttyShellFeature) -> Bool {
        guard let raw = currentDocument.effectiveValue(for: "shell-integration-features") else {
            return feature.isDefaultEnabled
        }
        let parts = raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        if parts.contains("no-\(feature.rawValue)") {
            return false
        }
        if parts.contains(feature.rawValue) {
            return true
        }
        return feature.isDefaultEnabled
    }

    /// Enables or disables an individual shell integration feature.
    public func setShellFeature(_ feature: GhosttyShellFeature, enabled: Bool) {
        var currentStates: [GhosttyShellFeature: Bool] = [:]
        for f in GhosttyShellFeature.allCases {
            currentStates[f] = isShellFeatureEnabled(f)
        }
        currentStates[feature] = enabled

        let formatted = GhosttyShellFeature.allCases.map { f -> String in
            let isOn = currentStates[f] ?? f.isDefaultEnabled
            return isOn ? f.rawValue : "no-\(f.rawValue)"
        }.joined(separator: ",")

        updateSetting(key: "shell-integration-features", value: formatted)
    }

    /// Raw working directory value configured in Ghostty (`working-directory`).
    public var workingDirectoryRaw: String {
        get {
            currentDocument.effectiveValue(for: "working-directory") ?? ""
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                removeSetting(key: "working-directory")
            } else {
                updateSetting(key: "working-directory", value: trimmed)
            }
        }
    }

    /// High-level working directory selection mode.
    public var workingDirectoryMode: GhosttyWorkingDirectoryMode {
        get {
            let raw = workingDirectoryRaw.trimmingCharacters(in: .whitespaces)
            if raw.isEmpty || raw == "inherit" {
                return .inherit
            } else if raw == "home" {
                return .home
            } else {
                return .custom
            }
        }
        set {
            switch newValue {
            case .inherit:
                updateSetting(key: "working-directory", value: "inherit")
            case .home:
                updateSetting(key: "working-directory", value: "home")
            case .custom:
                let current = workingDirectoryRaw.trimmingCharacters(in: .whitespaces)
                if current.isEmpty || current == "inherit" || current == "home" {
                    updateSetting(key: "working-directory", value: "~")
                }
            }
        }
    }

    /// Custom directory path when `workingDirectoryMode` is `.custom`.
    public var customWorkingDirectoryPath: String {
        get {
            let raw = workingDirectoryRaw.trimmingCharacters(in: .whitespaces)
            if raw == "inherit" || raw == "home" {
                return ""
            }
            return raw
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                updateSetting(key: "working-directory", value: "~")
            } else {
                updateSetting(key: "working-directory", value: trimmed)
            }
        }
    }

    /// Whether new windows inherit the working directory of the previously focused window.
    public var windowInheritWorkingDirectory: Bool {
        get {
            currentDocument.effectiveValue(for: "window-inherit-working-directory") != "false"
        }
        set {
            updateSetting(key: "window-inherit-working-directory", value: newValue ? "true" : "false")
        }
    }

    /// Whether new tabs inherit the working directory of the previously focused tab.
    public var tabInheritWorkingDirectory: Bool {
        get {
            currentDocument.effectiveValue(for: "tab-inherit-working-directory") != "false"
        }
        set {
            updateSetting(key: "tab-inherit-working-directory", value: newValue ? "true" : "false")
        }
    }

    /// Terminal type string exported to the `TERM` environment variable (Ghostty `term`).
    public var terminalType: String {
        get {
            currentDocument.effectiveValue(for: "term") ?? "xterm-ghostty"
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                removeSetting(key: "term")
            } else {
                updateSetting(key: "term", value: trimmed)
            }
        }
    }

    /// Parsed list of environment variables passed via repeated `env = KEY=VALUE` settings.
    public var environmentVariables: [GhosttyEnvVariable] {
        get {
            currentDocument.allValues(for: "env").compactMap { GhosttyEnvVariable.parse($0) }
        }
        set {
            let entries = newValue.map(\.formattedConfigEntry).filter { !$0.isEmpty }
            if entries.isEmpty {
                removeSetting(key: "env")
            } else {
                setRepeatedSettings(key: "env", values: entries)
            }
        }
    }

    /// Adds or updates an environment variable in the configuration in memory.
    public func addEnvironmentVariable(key: String, value: String) {
        let trimmedKey = key.trimmingCharacters(in: .whitespaces)
        guard !trimmedKey.isEmpty else { return }
        var current = environmentVariables
        if let idx = current.firstIndex(where: { $0.key == trimmedKey }) {
            current[idx].value = value
        } else {
            current.append(GhosttyEnvVariable(key: trimmedKey, value: value))
        }
        environmentVariables = current
    }

    /// Removes an environment variable by its key name.
    public func removeEnvironmentVariable(key: String) {
        var current = environmentVariables
        current.removeAll { $0.key == key }
        environmentVariables = current
    }
}
