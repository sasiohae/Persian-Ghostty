import XCTest
import SwiftUI
@testable import GhosttyPersian

@MainActor
final class PersianShellIntegrationTests: XCTestCase {
    private var tempDirectory: URL!
    private var fileManager: FileManager!

    override func setUp() {
        super.setUp()
        fileManager = FileManager.default
        tempDirectory = fileManager.temporaryDirectory.appendingPathComponent("PersianShellTests-\(UUID().uuidString)")
        try? fileManager.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        if let temp = tempDirectory {
            try? fileManager.removeItem(at: temp)
        }
        super.tearDown()
    }

    // MARK: - 1. Shell Detection Tests

    func testDetectActiveShellZsh() {
        let service = PersianShellIntegrationService(
            homeDirectory: tempDirectory,
            environment: ["SHELL": "/bin/zsh"],
            fileManager: fileManager
        )
        XCTAssertEqual(service.detectActiveShell(), .zsh)
    }

    func testDetectActiveShellZshHomebrew() {
        let service = PersianShellIntegrationService(
            homeDirectory: tempDirectory,
            environment: ["SHELL": "/opt/homebrew/bin/zsh"],
            fileManager: fileManager
        )
        XCTAssertEqual(service.detectActiveShell(), .zsh)
    }

    func testDetectActiveShellFish() {
        let service = PersianShellIntegrationService(
            homeDirectory: tempDirectory,
            environment: ["SHELL": "/opt/homebrew/bin/fish"],
            fileManager: fileManager
        )
        XCTAssertEqual(service.detectActiveShell(), .fish)
    }

    func testDetectActiveShellFishUsrLocal() {
        let service = PersianShellIntegrationService(
            homeDirectory: tempDirectory,
            environment: ["SHELL": "/usr/local/bin/fish"],
            fileManager: fileManager
        )
        XCTAssertEqual(service.detectActiveShell(), .fish)
    }

    func testDetectActiveShellFallbackToZsh() {
        let service = PersianShellIntegrationService(
            homeDirectory: tempDirectory,
            environment: ["SHELL": "/bin/sh"],
            fileManager: fileManager
        )
        XCTAssertEqual(service.detectActiveShell(), .zsh)
    }

    func testDetectActiveShellFishWhenConfigExistsAndNoZshrc() {
        let fishConfigDir = tempDirectory.appendingPathComponent(".config/fish", isDirectory: true)
        try? fileManager.createDirectory(at: fishConfigDir, withIntermediateDirectories: true)

        let service = PersianShellIntegrationService(
            homeDirectory: tempDirectory,
            environment: [:],
            fileManager: fileManager
        )
        XCTAssertEqual(service.detectActiveShell(), .fish)
    }

    // MARK: - 2. Hook Script Generation Tests

    func testZshHookGenerationContent() {
        let service = PersianShellIntegrationService(
            homeDirectory: tempDirectory,
            environment: [:],
            fileManager: fileManager
        )
        let script = service.generateHookScript(for: .zsh)

        XCTAssertTrue(script.contains(PersianShellMarkers.startMarker))
        XCTAssertTrue(script.contains(PersianShellMarkers.endMarker))
        XCTAssertTrue(script.contains("LC_CTYPE"))
        XCTAssertTrue(script.contains("setopt COMBINING_CHARS"))
        XCTAssertTrue(script.contains("fribidi"))
        XCTAssertTrue(script.contains("alias bidi="))
        XCTAssertTrue(script.contains("alias pcat="))
        XCTAssertTrue(script.contains("pecho()"))
    }

    func testFishHookGenerationContent() {
        let service = PersianShellIntegrationService(
            homeDirectory: tempDirectory,
            environment: [:],
            fileManager: fileManager
        )
        let script = service.generateHookScript(for: .fish)

        XCTAssertTrue(script.contains(PersianShellMarkers.startMarker))
        XCTAssertTrue(script.contains(PersianShellMarkers.endMarker))
        XCTAssertTrue(script.contains("set -q LC_CTYPE"))
        XCTAssertTrue(script.contains("type -q fribidi"))
        XCTAssertTrue(script.contains("alias bidi="))
        XCTAssertTrue(script.contains("alias pcat="))
        XCTAssertTrue(script.contains("function pecho"))
    }

    // MARK: - 3. BiDi Helper Availability Tests

    func testBiDiHelperAvailableWhenExecutableExists() {
        let mockExecutablePath = "/opt/homebrew/bin/fribidi"
        let service = PersianShellIntegrationService(
            homeDirectory: tempDirectory,
            environment: [:],
            fileManager: fileManager,
            isExecutableFile: { path in
                path == mockExecutablePath
            }
        )

        let (available, path) = service.checkBiDiHelperAvailability()
        XCTAssertTrue(available)
        XCTAssertEqual(path, mockExecutablePath)
    }

    func testBiDiHelperUnavailableWhenNoExecutable() {
        let service = PersianShellIntegrationService(
            homeDirectory: tempDirectory,
            environment: [:],
            fileManager: fileManager,
            isExecutableFile: { _ in false }
        )

        let (available, path) = service.checkBiDiHelperAvailability()
        XCTAssertFalse(available)
        XCTAssertNil(path)
    }

    // MARK: - 4. Zsh Installation & Safe Cleanup in Sandbox

    func testZshInstallWhenFileDoesNotExist() throws {
        let service = PersianShellIntegrationService(
            homeDirectory: tempDirectory,
            environment: [:],
            fileManager: fileManager
        )

        XCTAssertFalse(service.isInstalled(for: .zsh))

        let installedURL = try service.install(for: .zsh)
        XCTAssertTrue(fileManager.fileExists(atPath: installedURL.path))
        XCTAssertTrue(service.isInstalled(for: .zsh))

        let content = try String(contentsOf: installedURL, encoding: .utf8)
        XCTAssertTrue(content.contains(PersianShellMarkers.startMarker))
        XCTAssertTrue(content.contains(PersianShellMarkers.endMarker))
    }

    func testZshInstallPreservesExistingContent() throws {
        let zshrcURL = tempDirectory.appendingPathComponent(".zshrc")
        let userContent = "# User Custom Configuration\nexport PATH=\"$HOME/bin:$PATH\"\nalias gs=\"git status\"\n"
        try userContent.write(to: zshrcURL, atomically: true, encoding: .utf8)

        let service = PersianShellIntegrationService(
            homeDirectory: tempDirectory,
            environment: [:],
            fileManager: fileManager
        )

        try service.install(for: .zsh)

        let modifiedContent = try String(contentsOf: zshrcURL, encoding: .utf8)
        XCTAssertTrue(modifiedContent.contains("export PATH=\"$HOME/bin:$PATH\""))
        XCTAssertTrue(modifiedContent.contains("alias gs=\"git status\""))
        XCTAssertTrue(modifiedContent.contains(PersianShellMarkers.startMarker))
        XCTAssertTrue(modifiedContent.contains(PersianShellMarkers.endMarker))
        XCTAssertTrue(service.isInstalled(for: .zsh))
    }

    func testZshInstallIdempotentUpdate() throws {
        let service = PersianShellIntegrationService(
            homeDirectory: tempDirectory,
            environment: [:],
            fileManager: fileManager
        )

        try service.install(for: .zsh)
        try service.install(for: .zsh)

        let zshrcURL = tempDirectory.appendingPathComponent(".zshrc")
        let content = try String(contentsOf: zshrcURL, encoding: .utf8)

        // Ensure there is only 1 instance of start marker
        let startOccurrences = content.components(separatedBy: PersianShellMarkers.startMarker).count - 1
        XCTAssertEqual(startOccurrences, 1, "There should be exactly one integration block, no duplicate blocks.")
    }

    func testZshSafeCleanupRemovesOnlyIntegration() throws {
        let zshrcURL = tempDirectory.appendingPathComponent(".zshrc")
        let userPrefix = "# My Profile\nexport EDITOR=vim\n"
        let userSuffix = "\n# More aliases\nalias dev=\"cd ~/Developer\"\n"

        let service = PersianShellIntegrationService(
            homeDirectory: tempDirectory,
            environment: [:],
            fileManager: fileManager
        )

        try userPrefix.write(to: zshrcURL, atomically: true, encoding: .utf8)
        try service.install(for: .zsh)

        let midContent = try String(contentsOf: zshrcURL, encoding: .utf8)
        try (midContent + userSuffix).write(to: zshrcURL, atomically: true, encoding: .utf8)

        XCTAssertTrue(service.isInstalled(for: .zsh))

        // Now remove
        let removed = try service.remove(for: .zsh)
        XCTAssertTrue(removed)
        XCTAssertFalse(service.isInstalled(for: .zsh))

        let cleanedContent = try String(contentsOf: zshrcURL, encoding: .utf8)
        XCTAssertFalse(cleanedContent.contains(PersianShellMarkers.startMarker))
        XCTAssertFalse(cleanedContent.contains(PersianShellMarkers.endMarker))
        XCTAssertTrue(cleanedContent.contains("export EDITOR=vim"))
        XCTAssertTrue(cleanedContent.contains("alias dev=\"cd ~/Developer\""))
    }

    func testZshRemoveWhenNotInstalledIsSafeNoOp() throws {
        let service = PersianShellIntegrationService(
            homeDirectory: tempDirectory,
            environment: [:],
            fileManager: fileManager
        )

        let removed = try service.remove(for: .zsh)
        XCTAssertTrue(removed)
    }

    // MARK: - 5. Fish Installation & Safe Cleanup in Sandbox

    func testFishInstallInSandboxCreatesFile() throws {
        let service = PersianShellIntegrationService(
            homeDirectory: tempDirectory,
            environment: [:],
            fileManager: fileManager
        )

        XCTAssertFalse(service.isInstalled(for: .fish))

        let installedURL = try service.install(for: .fish)
        XCTAssertTrue(fileManager.fileExists(atPath: installedURL.path))
        XCTAssertTrue(service.isInstalled(for: .fish))

        let content = try String(contentsOf: installedURL, encoding: .utf8)
        XCTAssertTrue(content.contains(PersianShellMarkers.startMarker))
        XCTAssertTrue(content.contains(PersianShellMarkers.endMarker))
    }

    func testFishSafeCleanupRemovesFile() throws {
        let service = PersianShellIntegrationService(
            homeDirectory: tempDirectory,
            environment: [:],
            fileManager: fileManager
        )

        let installedURL = try service.install(for: .fish)
        XCTAssertTrue(fileManager.fileExists(atPath: installedURL.path))
        XCTAssertTrue(service.isInstalled(for: .fish))

        let removed = try service.remove(for: .fish)
        XCTAssertTrue(removed)
        XCTAssertFalse(fileManager.fileExists(atPath: installedURL.path))
        XCTAssertFalse(service.isInstalled(for: .fish))
    }

    func testFishRemoveWhenNotInstalledIsSafeNoOp() throws {
        let service = PersianShellIntegrationService(
            homeDirectory: tempDirectory,
            environment: [:],
            fileManager: fileManager
        )

        let removed = try service.remove(for: .fish)
        XCTAssertTrue(removed)
    }

    // MARK: - 6. Status and ViewModel Integration

    func testStatusModelIntegrity() throws {
        let service = PersianShellIntegrationService(
            homeDirectory: tempDirectory,
            environment: ["SHELL": "/bin/zsh"],
            fileManager: fileManager,
            isExecutableFile: { $0.contains("fribidi") }
        )

        var status = service.getStatus(for: .zsh)
        XCTAssertEqual(status.shell, .zsh)
        XCTAssertFalse(status.isInstalled)
        XCTAssertTrue(status.isBiDiHelperAvailable)

        try service.install(for: .zsh)

        status = service.getStatus(for: .zsh)
        XCTAssertTrue(status.isInstalled)
    }

    func testViewModelPersianShellIntegration() {
        let service = PersianShellIntegrationService(
            homeDirectory: tempDirectory,
            environment: ["SHELL": "/bin/zsh"],
            fileManager: fileManager
        )

        let vm = AppViewModel(persianShellService: service)
        XCTAssertEqual(vm.detectedShellType, .zsh)
        XCTAssertFalse(vm.isPersianShellInstalled(for: .zsh))

        let installed = vm.installPersianShellIntegration(for: .zsh)
        XCTAssertTrue(installed)
        XCTAssertTrue(vm.isPersianShellInstalled(for: .zsh))
        XCTAssertNotNil(vm.activeToast)
        XCTAssertEqual(vm.activeToast?.title, "Shell Integration Installed")

        let removed = vm.removePersianShellIntegration(for: .zsh)
        XCTAssertTrue(removed)
        XCTAssertFalse(vm.isPersianShellInstalled(for: .zsh))
        XCTAssertNotNil(vm.activeToast)
        XCTAssertEqual(vm.activeToast?.title, "Shell Integration Removed")
    }

    // MARK: - 7. View Instantiation Test

    func testPersianSettingsViewWithShellSupportInstantiates() {
        let view = PersianSettingsView()
        XCTAssertNotNil(view.body)
    }
}
