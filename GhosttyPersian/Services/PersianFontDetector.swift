import AppKit

/// Protocol for discovering and reporting Persian fonts on the system.
public protocol PersianFontDetecting: Sendable {
    func detectFonts() -> PersianDetectionReport
}

/// Discovers installed Persian fonts using `NSFontManager` or custom font providers.
public struct SystemPersianFontDetector: PersianFontDetecting {
    public struct CandidateSpec: Sendable, Equatable {
        public let name: String
        public let description: String
        public let isRecommended: Bool

        public init(name: String, description: String, isRecommended: Bool = false) {
            self.name = name
            self.description = description
            self.isRecommended = isRecommended
        }
    }

    /// Curated list of high-quality Persian fonts for terminal and UI use.
    public static let standardCandidates: [CandidateSpec] = [
        CandidateSpec(
            name: "Vazirmatn",
            description: "Modern, universal Persian typeface by Saber Rastikerdar with complete Unicode coverage.",
            isRecommended: true
        ),
        CandidateSpec(
            name: "Vazir",
            description: "Classic beloved Persian typeface, widely adopted across Iranian open-source projects.",
            isRecommended: true
        ),
        CandidateSpec(
            name: "Vazir Code",
            description: "Monospaced Persian programming font optimized for terminal and IDE environments.",
            isRecommended: true
        ),
        CandidateSpec(
            name: "IRANSansWeb",
            description: "Contemporary Persian interface typeface widely used in modern applications.",
            isRecommended: false
        ),
        CandidateSpec(
            name: "Yekan Bakh",
            description: "Geometric and legible modern Persian sans-serif typeface.",
            isRecommended: false
        ),
        CandidateSpec(
            name: "Sahel",
            description: "Balanced, soft Persian typeface designed for screen legibility.",
            isRecommended: false
        ),
        CandidateSpec(
            name: "Shabnam",
            description: "Clear and modern Persian typeface built upon Vazir foundations.",
            isRecommended: false
        ),
        CandidateSpec(
            name: "Samim",
            description: "Friendly and rounded Persian typeface for accessible readability.",
            isRecommended: false
        ),
        CandidateSpec(
            name: "Iranian Sans",
            description: "Standard open-source Persian sans-serif typeface.",
            isRecommended: false
        )
    ]

    private let availableFamiliesProvider: @Sendable () -> Set<String>

    public init(
        availableFamiliesProvider: @escaping @Sendable () -> Set<String> = {
            Set(NSFontManager.shared.availableFontFamilies)
        }
    ) {
        self.availableFamiliesProvider = availableFamiliesProvider
    }

    public func detectFonts() -> PersianDetectionReport {
        let installedFamilies = availableFamiliesProvider()

        var installed: [PersianFontCandidate] = []
        var uninstalled: [PersianFontCandidate] = []

        for candidate in Self.standardCandidates {
            let isFound = installedFamilies.contains(candidate.name)
            let item = PersianFontCandidate(
                name: candidate.name,
                description: candidate.description,
                isInstalled: isFound,
                isRecommended: candidate.isRecommended
            )
            if isFound {
                installed.append(item)
            } else {
                uninstalled.append(item)
            }
        }

        return PersianDetectionReport(installedFonts: installed, uninstalledFonts: uninstalled)
    }
}
