import XCTest
@testable import GhosttyPersian

final class PathResolutionResiliencyTests: XCTestCase {
    private let mockHome = URL(fileURLWithPath: "/Users/sandboxuser")

    // MARK: - 1. Missing Directory Resiliency

    func testMissingDirectoriesDoesNotCrash() {
        let resolver = GhosttyConfigPathResolver(
            homeDirectory: mockHome,
            environment: [:],
            fileExists: { _ in false }
        )

        let candidates = resolver.candidatePaths()
        XCTAssertEqual(candidates.count, 4)
        XCTAssertTrue(resolver.existingPaths().isEmpty)
        XCTAssertNil(resolver.effectiveConfigurationPath())
        XCTAssertEqual(resolver.defaultRecommendedPath.path, "/Users/sandboxuser/Library/Application Support/com.mitchellh.ghostty/config")
    }

    // MARK: - 2. Broken Symlink Resiliency

    func testBrokenSymlinksAreNotTreatedAsExisting() {
        // Broken symlink returns false from fileExists
        var existingSet: Set<String> = []
        let brokenSymlinkPath = "/Users/sandboxuser/.config/ghostty/config.ghostty"
        let validFallbackPath = "/Users/sandboxuser/.config/ghostty/config"
        existingSet.insert(validFallbackPath)

        let resolver = GhosttyConfigPathResolver(
            homeDirectory: mockHome,
            environment: [:],
            fileExists: { existingSet.contains($0.path) }
        )

        let effective = resolver.effectiveConfigurationPath()
        XCTAssertNotNil(effective)
        XCTAssertEqual(effective?.url.path, validFallbackPath)
        XCTAssertFalse(resolver.existingPaths().contains(where: { $0.url.path == brokenSymlinkPath }))
    }

    // MARK: - 3. Complete Precedence Cascading Across All 4 Candidates

    func testFullFourLevelPrecedenceCascade() {
        let p1 = "/Users/sandboxuser/.config/ghostty/config.ghostty"
        let p2 = "/Users/sandboxuser/.config/ghostty/config"
        let p3 = "/Users/sandboxuser/Library/Application Support/com.mitchellh.ghostty/config.ghostty"
        let p4 = "/Users/sandboxuser/Library/Application Support/com.mitchellh.ghostty/config"

        var existing: Set<String> = [p1, p2, p3, p4]

        let resolver = GhosttyConfigPathResolver(
            homeDirectory: mockHome,
            environment: [:],
            fileExists: { existing.contains($0.path) }
        )

        // Level 4 (Highest): macOS config
        XCTAssertEqual(resolver.effectiveConfigurationPath()?.url.path, p4)
        XCTAssertEqual(resolver.effectiveConfigurationPath()?.precedenceOrder, 4)

        // Delete level 4 -> Level 3: macOS config.ghostty
        existing.remove(p4)
        XCTAssertEqual(resolver.effectiveConfigurationPath()?.url.path, p3)
        XCTAssertEqual(resolver.effectiveConfigurationPath()?.precedenceOrder, 3)

        // Delete level 3 -> Level 2: XDG config
        existing.remove(p3)
        XCTAssertEqual(resolver.effectiveConfigurationPath()?.url.path, p2)
        XCTAssertEqual(resolver.effectiveConfigurationPath()?.precedenceOrder, 2)

        // Delete level 2 -> Level 1: XDG config.ghostty
        existing.remove(p2)
        XCTAssertEqual(resolver.effectiveConfigurationPath()?.url.path, p1)
        XCTAssertEqual(resolver.effectiveConfigurationPath()?.precedenceOrder, 1)

        // Delete level 1 -> None
        existing.remove(p1)
        XCTAssertNil(resolver.effectiveConfigurationPath())
    }

    // MARK: - 4. XDG_CONFIG_HOME Edge Cases

    func testXDGConfigHomeWhitespaceAndEmptyFallback() {
        // Whitespace only should fall back to default ~/.config
        let whitespaceEnv = ["XDG_CONFIG_HOME": "   \t  "]
        let resolverWhitespace = GhosttyConfigPathResolver(
            homeDirectory: mockHome,
            environment: whitespaceEnv,
            fileExists: { _ in false }
        )
        XCTAssertEqual(resolverWhitespace.xdgConfigDirectory.path, "/Users/sandboxuser/.config")

        // Empty string should fall back to default ~/.config
        let emptyEnv = ["XDG_CONFIG_HOME": ""]
        let resolverEmpty = GhosttyConfigPathResolver(
            homeDirectory: mockHome,
            environment: emptyEnv,
            fileExists: { _ in false }
        )
        XCTAssertEqual(resolverEmpty.xdgConfigDirectory.path, "/Users/sandboxuser/.config")
    }

    func testXDGConfigHomeWithTrailingSlash() {
        let env = ["XDG_CONFIG_HOME": "/custom/xdg/dir/"]
        let resolver = GhosttyConfigPathResolver(
            homeDirectory: mockHome,
            environment: env,
            fileExists: { _ in false }
        )
        let candidates = resolver.candidatePaths()
        XCTAssertTrue(candidates[0].url.path.contains("/custom/xdg/dir/ghostty/config.ghostty"))
    }
}
