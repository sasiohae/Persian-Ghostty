import XCTest
import SwiftUI
@testable import GhosttyPersian

@MainActor
final class ShellSettingsTests: XCTestCase {
    // 1. Shell command overrides and clearing
    func testShellCommand() {
        let vm = AppViewModel()
        XCTAssertEqual(vm.shellCommand, "")
        XCTAssertNil(vm.getEffectiveValue(for: "command"))

        vm.shellCommand = "/bin/zsh"
        XCTAssertEqual(vm.shellCommand, "/bin/zsh")
        XCTAssertEqual(vm.getEffectiveValue(for: "command"), "/bin/zsh")

        vm.shellCommand = "/opt/homebrew/bin/fish -l"
        XCTAssertEqual(vm.shellCommand, "/opt/homebrew/bin/fish -l")
        XCTAssertEqual(vm.getEffectiveValue(for: "command"), "/opt/homebrew/bin/fish -l")

        // Clearing command removes setting to revert to $SHELL default
        vm.shellCommand = "   "
        XCTAssertEqual(vm.shellCommand, "")
        XCTAssertNil(vm.getEffectiveValue(for: "command"))
    }

    // 2. Shell integration mode selection
    func testShellIntegrationMode() {
        let vm = AppViewModel()
        XCTAssertEqual(vm.shellIntegration, .detect)

        vm.shellIntegration = .zsh
        XCTAssertEqual(vm.shellIntegration, .zsh)
        XCTAssertEqual(vm.getEffectiveValue(for: "shell-integration"), "zsh")

        vm.shellIntegration = .none
        XCTAssertEqual(vm.shellIntegration, .none)
        XCTAssertEqual(vm.getEffectiveValue(for: "shell-integration"), "none")

        vm.shellIntegration = .fish
        XCTAssertEqual(vm.shellIntegration, .fish)
        XCTAssertEqual(vm.getEffectiveValue(for: "shell-integration"), "fish")

        vm.shellIntegration = .detect
        XCTAssertEqual(vm.shellIntegration, .detect)
        XCTAssertEqual(vm.getEffectiveValue(for: "shell-integration"), "detect")
    }

    // 3. Shell integration features toggling and formatting
    func testShellIntegrationFeatures() {
        let vm = AppViewModel()
        // Default expectations
        XCTAssertTrue(vm.isShellFeatureEnabled(.cursor))
        XCTAssertFalse(vm.isShellFeatureEnabled(.sudo))
        XCTAssertTrue(vm.isShellFeatureEnabled(.title))
        XCTAssertFalse(vm.isShellFeatureEnabled(.sshEnv))
        XCTAssertFalse(vm.isShellFeatureEnabled(.sshTerminfo))
        XCTAssertTrue(vm.isShellFeatureEnabled(.path))

        // Enable sudo and ssh-env
        vm.setShellFeature(.sudo, enabled: true)
        vm.setShellFeature(.sshEnv, enabled: true)
        XCTAssertTrue(vm.isShellFeatureEnabled(.sudo))
        XCTAssertTrue(vm.isShellFeatureEnabled(.sshEnv))

        let raw = vm.shellIntegrationFeaturesRaw
        XCTAssertTrue(raw.contains("sudo"))
        XCTAssertFalse(raw.contains("no-sudo"))
        XCTAssertTrue(raw.contains("ssh-env"))
        XCTAssertFalse(raw.contains("no-ssh-env"))

        // Disable cursor
        vm.setShellFeature(.cursor, enabled: false)
        XCTAssertFalse(vm.isShellFeatureEnabled(.cursor))
        XCTAssertTrue(vm.shellIntegrationFeaturesRaw.contains("no-cursor"))
    }

    // 4. Working directory modes and directory inheritance
    func testWorkingDirectoryAndInheritance() {
        let vm = AppViewModel()
        XCTAssertEqual(vm.workingDirectoryMode, .inherit)
        XCTAssertTrue(vm.windowInheritWorkingDirectory)
        XCTAssertTrue(vm.tabInheritWorkingDirectory)

        vm.workingDirectoryMode = .home
        XCTAssertEqual(vm.workingDirectoryMode, .home)
        XCTAssertEqual(vm.getEffectiveValue(for: "working-directory"), "home")

        vm.customWorkingDirectoryPath = "~/Developer/Projects"
        XCTAssertEqual(vm.workingDirectoryMode, .custom)
        XCTAssertEqual(vm.customWorkingDirectoryPath, "~/Developer/Projects")
        XCTAssertEqual(vm.getEffectiveValue(for: "working-directory"), "~/Developer/Projects")

        vm.windowInheritWorkingDirectory = false
        XCTAssertFalse(vm.windowInheritWorkingDirectory)
        XCTAssertEqual(vm.getEffectiveValue(for: "window-inherit-working-directory"), "false")

        vm.tabInheritWorkingDirectory = false
        XCTAssertFalse(vm.tabInheritWorkingDirectory)
        XCTAssertEqual(vm.getEffectiveValue(for: "tab-inherit-working-directory"), "false")
    }

    // 5. Terminal type and environment variables
    func testTerminalTypeAndEnvironmentVariables() {
        let vm = AppViewModel()
        XCTAssertEqual(vm.terminalType, "xterm-ghostty")
        XCTAssertTrue(vm.environmentVariables.isEmpty)

        vm.terminalType = "xterm-256color"
        XCTAssertEqual(vm.terminalType, "xterm-256color")
        XCTAssertEqual(vm.getEffectiveValue(for: "term"), "xterm-256color")

        // Add environment variables
        vm.addEnvironmentVariable(key: "COLORTERM", value: "truecolor")
        vm.addEnvironmentVariable(key: "EDITOR", value: "nano")

        XCTAssertEqual(vm.environmentVariables.count, 2)
        XCTAssertEqual(vm.environmentVariables[0].key, "COLORTERM")
        XCTAssertEqual(vm.environmentVariables[0].value, "truecolor")
        XCTAssertEqual(vm.environmentVariables[1].key, "EDITOR")
        XCTAssertEqual(vm.environmentVariables[1].value, "nano")

        let allEnv = vm.getAllValues(for: "env")
        XCTAssertEqual(allEnv, ["COLORTERM=truecolor", "EDITOR=nano"])

        // Remove one variable
        if let first = vm.environmentVariables.first {
            vm.removeEnvironmentVariable(key: first.key)
        }
        XCTAssertEqual(vm.environmentVariables.count, 1)
        XCTAssertEqual(vm.environmentVariables[0].key, "EDITOR")
    }

    // 6. Non-destructive preservation of comments and unmanaged keys
    func testNonDestructivePreservationWithShellSettings() async {
        let source = """
        # Custom Shell setup
        unmanaged-plugin = active

        command = /bin/sh
        working-directory = /tmp

        # End of shell setup
        """
        let doc = GhosttyConfigParser().parse(source)
        let mockRepo = MockRepo(loadedDoc: doc)
        let vm = AppViewModel(repository: mockRepo, cliService: MockCLI())
        await vm.loadConfiguration()

        vm.shellCommand = "/bin/zsh"
        vm.workingDirectoryMode = .home
        vm.shellIntegration = .detect

        let serialized = vm.currentDocument.serialize()
        XCTAssertTrue(serialized.contains("# Custom Shell setup"))
        XCTAssertTrue(serialized.contains("unmanaged-plugin = active"))
        XCTAssertTrue(serialized.contains("command = /bin/zsh"))
        XCTAssertTrue(serialized.contains("working-directory = home"))
        XCTAssertTrue(serialized.contains("shell-integration = detect"))
        XCTAssertTrue(serialized.contains("# End of shell setup"))
    }

    // 7. ShellSettingsView instantiates and evaluates body
    func testShellSettingsViewInstantiates() {
        let view = ShellSettingsView()
        XCTAssertNotNil(view.body)
    }
}

// MARK: - Test Mocks

private final class MockRepo: GhosttyConfigRepositoryProtocol, @unchecked Sendable {
    var pathResolver: GhosttyConfigPathResolver = GhosttyConfigPathResolver()
    var loadedDoc: GhosttyConfigDocument

    init(loadedDoc: GhosttyConfigDocument) {
        self.loadedDoc = loadedDoc
    }

    func discoverEffectivePath() -> GhosttyConfigPath? {
        GhosttyConfigPath(url: URL(fileURLWithPath: "/test/config"), scope: .macOS, exists: true, precedenceOrder: 4)
    }

    func loadEffectiveConfiguration() throws -> LoadedConfiguration? {
        LoadedConfiguration(
            path: GhosttyConfigPath(url: URL(fileURLWithPath: "/test/config"), scope: .macOS, exists: true, precedenceOrder: 4),
            document: loadedDoc,
            rawContent: loadedDoc.serialize()
        )
    }

    func readConfiguration(at url: URL) throws -> LoadedConfiguration {
        LoadedConfiguration(
            path: GhosttyConfigPath(url: url, scope: .macOS, exists: true, precedenceOrder: 4),
            document: loadedDoc,
            rawContent: loadedDoc.serialize()
        )
    }

    func saveConfiguration(document: GhosttyConfigDocument, to targetURL: URL?, createBackup: Bool, validate: Bool) throws -> SaveResult {
        SaveResult(targetURL: targetURL ?? URL(fileURLWithPath: "/test"), backupURL: nil, validationResult: .valid, document: document)
    }

    func createBackup(for sourceURL: URL) throws -> GhosttyBackupInfo {
        GhosttyBackupInfo(url: sourceURL, fileName: "b.bak", creationDate: Date(), sizeInBytes: 0)
    }

    func listBackups() throws -> [GhosttyBackupInfo] { [] }

    func restoreBackup(from backupURL: URL, to targetURL: URL?, validate: Bool) throws -> SaveResult {
        SaveResult(targetURL: targetURL ?? backupURL, backupURL: nil, validationResult: .valid, document: GhosttyConfigDocument())
    }
}

private final class MockCLI: GhosttyCLIServiceProtocol, @unchecked Sendable {
    func isGhosttyInstalled() -> Bool { true }
    func executableURL() throws -> URL { URL(fileURLWithPath: "/test/ghostty") }
    func validateConfig(at fileURL: URL) throws -> GhosttyValidationResult { .valid }
    func listFonts() throws -> [GhosttyFontFamily] { [] }
    func listThemes(colorScheme: GhosttyThemeColorScheme) throws -> [GhosttyTheme] { [] }
    func getDefaultConfigDocument() throws -> GhosttyConfigDocument { GhosttyConfigDocument() }
    func getVersion() throws -> String { "Ghostty 1.3.1" }
}
