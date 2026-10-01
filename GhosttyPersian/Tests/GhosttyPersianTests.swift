import XCTest
@testable import GhosttyPersian

final class GhosttyPersianTests: XCTestCase {
    func testNavigationSectionsCount() {
        XCTAssertEqual(NavigationSection.allCases.count, 7)
    }

    func testInitialNavigationSectionsMatchSpecification() {
        let expectedSections: [NavigationSection] = [
            .general,
            .typography,
            .persian,
            .appearance,
            .window,
            .shell,
            .config
        ]
        XCTAssertEqual(NavigationSection.allCases, expectedSections)
    }

    func testSectionTitles() {
        XCTAssertEqual(NavigationSection.general.title, "General")
        XCTAssertEqual(NavigationSection.typography.title, "Typography")
        XCTAssertEqual(NavigationSection.persian.title, "Persian")
        XCTAssertEqual(NavigationSection.appearance.title, "Appearance")
        XCTAssertEqual(NavigationSection.window.title, "Window")
        XCTAssertEqual(NavigationSection.shell.title, "Shell")
        XCTAssertEqual(NavigationSection.config.title, "Config")
    }
}
