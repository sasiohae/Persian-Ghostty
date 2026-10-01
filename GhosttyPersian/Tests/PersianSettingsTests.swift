import XCTest
import SwiftUI
@testable import GhosttyPersian

@MainActor
final class PersianSettingsTests: XCTestCase {
    // 1. Font detector reports installed and uninstalled fonts accurately
    func testPersianFontDetectorWithMockFonts() {
        let mockFamilies: Set<String> = ["Vazirmatn", "IRANSansWeb", "Monaco", "Menlo"]
        let detector = SystemPersianFontDetector(availableFamiliesProvider: { mockFamilies })

        let report = detector.detectFonts()
        XCTAssertTrue(report.isVazirFamilyInstalled)
        XCTAssertEqual(report.recommendedFontName, "Vazirmatn")

        let installedNames = Set(report.installedFonts.map(\.name))
        XCTAssertTrue(installedNames.contains("Vazirmatn"))
        XCTAssertTrue(installedNames.contains("IRANSansWeb"))
        XCTAssertFalse(installedNames.contains("Sahel"))

        let uninstalledNames = Set(report.uninstalledFonts.map(\.name))
        XCTAssertTrue(uninstalledNames.contains("Sahel"))
        XCTAssertTrue(uninstalledNames.contains("Shabnam"))
    }

    // 2. Font detector when Vazir is not installed selects other installed Persian font
    func testPersianFontDetectorWhenNoVazir() {
        let mockFamilies: Set<String> = ["Yekan Bakh"]
        let detector = SystemPersianFontDetector(availableFamiliesProvider: { mockFamilies })

        let report = detector.detectFonts()
        XCTAssertFalse(report.isVazirFamilyInstalled)
        XCTAssertEqual(report.recommendedFontName, "Yekan Bakh")
    }

    // 3. Set Persian font as primary
    func testSetPersianAsPrimary() {
        let vm = AppViewModel()
        vm.fallbackFontFamilies = ["Fira Code"]

        vm.setPersianAsPrimary(fontName: "Vazirmatn")
        XCTAssertEqual(vm.primaryFontFamily, "Vazirmatn")
        XCTAssertTrue(vm.isPersianConfigured)
        XCTAssertTrue(vm.isPersianPrimary)
        XCTAssertFalse(vm.isPersianFallback)
        XCTAssertEqual(vm.configuredPersianFontName, "Vazirmatn")
        XCTAssertEqual(vm.fallbackFontFamilies, ["Fira Code"])
    }

    // 4. Add Persian font as fallback (recommended coding workflow)
    func testAddPersianAsFallback() {
        let vm = AppViewModel()
        vm.primaryFontFamily = "JetBrains Mono"

        vm.addPersianAsFallback(fontName: "Vazir")
        XCTAssertEqual(vm.primaryFontFamily, "JetBrains Mono")
        XCTAssertTrue(vm.fallbackFontFamilies.contains("Vazir"))
        XCTAssertTrue(vm.isPersianConfigured)
        XCTAssertFalse(vm.isPersianPrimary)
        XCTAssertTrue(vm.isPersianFallback)
        XCTAssertEqual(vm.configuredPersianFontName, "Vazir")
    }

    // 5. Remove Persian font
    func testRemovePersianFont() {
        let vm = AppViewModel()
        vm.primaryFontFamily = "JetBrains Mono"
        vm.addPersianAsFallback(fontName: "Vazir")
        XCTAssertTrue(vm.isPersianConfigured)

        vm.removePersianFont(fontName: "Vazir")
        XCTAssertFalse(vm.fallbackFontFamilies.contains("Vazir"))
        XCTAssertFalse(vm.isPersianConfigured)
    }

    // 6. Apply recommended Persian metrics and verification
    func testApplyRecommendedPersianMetrics() {
        let vm = AppViewModel()
        XCTAssertFalse(vm.areRecommendedPersianMetricsApplied)

        vm.applyRecommendedPersianMetrics()
        XCTAssertTrue(vm.areRecommendedPersianMetricsApplied)
        XCTAssertEqual(vm.adjustCellHeight, "15%")
        XCTAssertEqual(vm.adjustFontBaseline, "1")
        XCTAssertTrue(vm.fontThicken)
        XCTAssertEqual(vm.getEffectiveValue(for: "adjust-cell-height"), "15%")
        XCTAssertEqual(vm.getEffectiveValue(for: "adjust-font-baseline"), "1")
        XCTAssertEqual(vm.getEffectiveValue(for: "font-thicken"), "true")
    }

    // 7. PersianSettingsView instantiates and renders
    func testPersianSettingsViewInstantiates() {
        let view = PersianSettingsView()
        XCTAssertNotNil(view.body)
    }
}
