import XCTest
@testable import GhosttyPersian

final class GhosttyConfigPathResolverTests: XCTestCase {
    private let mockHome = URL(fileURLWithPath: "/Users/testuser")

    // 1. Candidate paths match specification and order
    func testCandidatePathsDefault() {
        let resolver = GhosttyConfigPathResolver(
            homeDirectory: mockHome,
            environment: [:],
            fileExists: { _ in false }
        )

        let candidates = resolver.candidatePaths()
        XCTAssertEqual(candidates.count, 4)

        // 1. XDG config.ghostty
        XCTAssertEqual(candidates[0].url.path, "/Users/testuser/.config/ghostty/config.ghostty")
        XCTAssertEqual(candidates[0].scope, .xdg)
        XCTAssertEqual(candidates[0].precedenceOrder, 1)

        // 2. XDG config
        XCTAssertEqual(candidates[1].url.path, "/Users/testuser/.config/ghostty/config")
        XCTAssertEqual(candidates[1].scope, .xdg)
        XCTAssertEqual(candidates[1].precedenceOrder, 2)

        // 3. macOS Application Support config.ghostty
        XCTAssertEqual(candidates[2].url.path, "/Users/testuser/Library/Application Support/com.mitchellh.ghostty/config.ghostty")
        XCTAssertEqual(candidates[2].scope, .macOS)
        XCTAssertEqual(candidates[2].precedenceOrder, 3)

        // 4. macOS Application Support config
        XCTAssertEqual(candidates[3].url.path, "/Users/testuser/Library/Application Support/com.mitchellh.ghostty/config")
        XCTAssertEqual(candidates[3].scope, .macOS)
        XCTAssertEqual(candidates[3].precedenceOrder, 4)
    }

    // 2. Custom XDG_CONFIG_HOME environment variable
    func testCustomXDGConfigHome() {
        let env = ["XDG_CONFIG_HOME": "/custom/xdg/path"]
        let resolver = GhosttyConfigPathResolver(
            homeDirectory: mockHome,
            environment: env,
            fileExists: { _ in false }
        )

        let candidates = resolver.candidatePaths()
        XCTAssertEqual(candidates[0].url.path, "/custom/xdg/path/ghostty/config.ghostty")
        XCTAssertEqual(candidates[1].url.path, "/custom/xdg/path/ghostty/config")
    }

    // 3. Effective path when only XDG exists
    func testEffectivePathWhenOnlyXDGExists() {
        let existingPaths: Set<String> = [
            "/Users/testuser/.config/ghostty/config"
        ]

        let resolver = GhosttyConfigPathResolver(
            homeDirectory: mockHome,
            environment: [:],
            fileExists: { existingPaths.contains($0.path) }
        )

        XCTAssertEqual(resolver.existingPaths().count, 1)
        let effective = resolver.effectiveConfigurationPath()
        XCTAssertNotNil(effective)
        XCTAssertEqual(effective?.url.path, "/Users/testuser/.config/ghostty/config")
        XCTAssertEqual(effective?.scope, .xdg)
    }

    // 4. Effective path when only macOS exists
    func testEffectivePathWhenOnlyMacOSExists() {
        let existingPaths: Set<String> = [
            "/Users/testuser/Library/Application Support/com.mitchellh.ghostty/config"
        ]

        let resolver = GhosttyConfigPathResolver(
            homeDirectory: mockHome,
            environment: [:],
            fileExists: { existingPaths.contains($0.path) }
        )

        XCTAssertEqual(resolver.existingPaths().count, 1)
        let effective = resolver.effectiveConfigurationPath()
        XCTAssertNotNil(effective)
        XCTAssertEqual(effective?.url.path, "/Users/testuser/Library/Application Support/com.mitchellh.ghostty/config")
        XCTAssertEqual(effective?.scope, .macOS)
    }

    // 5. Precedence: macOS overrides XDG when both exist
    func testPrecedenceWhenBothXDGAndMacOSExist() {
        let existingPaths: Set<String> = [
            "/Users/testuser/.config/ghostty/config",
            "/Users/testuser/Library/Application Support/com.mitchellh.ghostty/config"
        ]

        let resolver = GhosttyConfigPathResolver(
            homeDirectory: mockHome,
            environment: [:],
            fileExists: { existingPaths.contains($0.path) }
        )

        let existing = resolver.existingPaths()
        XCTAssertEqual(existing.count, 2)

        // macOS must take precedence over XDG
        let effective = resolver.effectiveConfigurationPath()
        XCTAssertNotNil(effective)
        XCTAssertEqual(effective?.scope, .macOS)
        XCTAssertEqual(effective?.url.path, "/Users/testuser/Library/Application Support/com.mitchellh.ghostty/config")
    }

    // 6. Precedence: config overrides config.ghostty within same scope
    func testPrecedenceWithinSameScope() {
        let existingPaths: Set<String> = [
            "/Users/testuser/.config/ghostty/config.ghostty",
            "/Users/testuser/.config/ghostty/config"
        ]

        let resolver = GhosttyConfigPathResolver(
            homeDirectory: mockHome,
            environment: [:],
            fileExists: { existingPaths.contains($0.path) }
        )

        let effective = resolver.effectiveConfigurationPath()
        XCTAssertNotNil(effective)
        XCTAssertEqual(effective?.url.path, "/Users/testuser/.config/ghostty/config")
    }

    // 7. No files exist returns nil effective path and standard default
    func testNoFilesExist() {
        let resolver = GhosttyConfigPathResolver(
            homeDirectory: mockHome,
            environment: [:],
            fileExists: { _ in false }
        )

        XCTAssertTrue(resolver.existingPaths().isEmpty)
        XCTAssertNil(resolver.effectiveConfigurationPath())
        XCTAssertEqual(
            resolver.defaultRecommendedPath.path,
            "/Users/testuser/Library/Application Support/com.mitchellh.ghostty/config"
        )
    }
}
