import XCTest
@testable import GhosttyPersian

final class GhosttyExecutableLocatorTests: XCTestCase {
    // 1. Finding via custom path override
    func testFindCustomPath() {
        let customURL = URL(fileURLWithPath: "/custom/bin/ghostty")
        let locator = GhosttyExecutableLocator(
            customPath: customURL,
            environment: [:],
            isExecutableFile: { $0 == "/custom/bin/ghostty" }
        )

        XCTAssertTrue(locator.isGhosttyInstalled())
        XCTAssertEqual(locator.findExecutable(), customURL)
    }

    // 2. Finding standard /Applications bundle
    func testFindApplicationsBundle() {
        let locator = GhosttyExecutableLocator(
            customPath: nil,
            environment: [:],
            isExecutableFile: { $0 == "/Applications/Ghostty.app/Contents/MacOS/ghostty" }
        )

        XCTAssertTrue(locator.isGhosttyInstalled())
        XCTAssertEqual(
            locator.findExecutable()?.path,
            "/Applications/Ghostty.app/Contents/MacOS/ghostty"
        )
    }

    // 3. Finding in user Applications directory
    func testFindUserApplicationsBundle() {
        let env = ["HOME": "/Users/testuser"]
        let expected = "/Users/testuser/Applications/Ghostty.app/Contents/MacOS/ghostty"

        let locator = GhosttyExecutableLocator(
            customPath: nil,
            environment: env,
            isExecutableFile: { $0 == expected }
        )

        XCTAssertTrue(locator.isGhosttyInstalled())
        XCTAssertEqual(locator.findExecutable()?.path, expected)
    }

    // 4. Finding in Homebrew path
    func testFindHomebrewPath() {
        let locator = GhosttyExecutableLocator(
            customPath: nil,
            environment: [:],
            isExecutableFile: { $0 == "/opt/homebrew/bin/ghostty" }
        )

        XCTAssertTrue(locator.isGhosttyInstalled())
        XCTAssertEqual(locator.findExecutable()?.path, "/opt/homebrew/bin/ghostty")
    }

    // 5. Finding in /usr/local/bin
    func testFindUsrLocalBin() {
        let locator = GhosttyExecutableLocator(
            customPath: nil,
            environment: [:],
            isExecutableFile: { $0 == "/usr/local/bin/ghostty" }
        )

        XCTAssertTrue(locator.isGhosttyInstalled())
        XCTAssertEqual(locator.findExecutable()?.path, "/usr/local/bin/ghostty")
    }

    // 6. Finding in custom PATH directory
    func testFindInCustomPathEnvironment() {
        let env = ["PATH": "/opt/custom/bin:/another/bin"]
        let locator = GhosttyExecutableLocator(
            customPath: nil,
            environment: env,
            isExecutableFile: { $0 == "/opt/custom/bin/ghostty" }
        )

        XCTAssertTrue(locator.isGhosttyInstalled())
        XCTAssertEqual(locator.findExecutable()?.path, "/opt/custom/bin/ghostty")
    }

    // 7. Not found when no executable exists
    func testExecutableNotFound() {
        let locator = GhosttyExecutableLocator(
            customPath: nil,
            environment: [:],
            isExecutableFile: { _ in false }
        )

        XCTAssertFalse(locator.isGhosttyInstalled())
        XCTAssertNil(locator.findExecutable())
    }

    // 8. Candidate paths precedence
    func testCandidatePathsOrder() {
        let customURL = URL(fileURLWithPath: "/my/ghostty")
        let locator = GhosttyExecutableLocator(
            customPath: customURL,
            environment: ["HOME": "/Users/alice", "PATH": "/bin:/usr/bin"],
            isExecutableFile: { _ in false }
        )

        let candidates = locator.candidatePaths()
        XCTAssertEqual(candidates[0], "/my/ghostty")
        XCTAssertEqual(candidates[1], "/Applications/Ghostty.app/Contents/MacOS/ghostty")
        XCTAssertEqual(candidates[2], "/Users/alice/Applications/Ghostty.app/Contents/MacOS/ghostty")
        XCTAssertEqual(candidates[3], "/opt/homebrew/bin/ghostty")
        XCTAssertEqual(candidates[4], "/usr/local/bin/ghostty")
        XCTAssertTrue(candidates.contains("/bin/ghostty"))
        XCTAssertTrue(candidates.contains("/usr/bin/ghostty"))
    }
}
