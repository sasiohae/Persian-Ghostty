import Foundation

/// Describes a Persian font candidate and its local installation status.
public struct PersianFontCandidate: Identifiable, Sendable, Equatable, Hashable {
    public var id: String { name }

    /// The font family name (e.g., "Vazirmatn", "Vazir", "IRANSansWeb").
    public let name: String

    /// Brief description of the font.
    public let description: String

    /// Whether this font is detected on the local system.
    public let isInstalled: Bool

    /// Whether this font is recommended by the application.
    public let isRecommended: Bool

    public init(
        name: String,
        description: String,
        isInstalled: Bool,
        isRecommended: Bool = false
    ) {
        self.name = name
        self.description = description
        self.isInstalled = isInstalled
        self.isRecommended = isRecommended
    }
}

/// Comprehensive report on Persian font availability and recommendations.
public struct PersianDetectionReport: Sendable, Equatable {
    /// Persian fonts that were found on the system.
    public let installedFonts: [PersianFontCandidate]

    /// Persian fonts that are not installed locally.
    public let uninstalledFonts: [PersianFontCandidate]

    /// Whether any variant of the Vazir family (Vazirmatn, Vazir, Vazir Code) is installed.
    public var isVazirFamilyInstalled: Bool {
        installedFonts.contains { $0.name.hasPrefix("Vazir") }
    }

    /// The recommended font to use, prioritizing Vazirmatn, then Vazir, then other installed fonts.
    public var recommendedFontName: String? {
        if installedFonts.contains(where: { $0.name == "Vazirmatn" }) {
            return "Vazirmatn"
        }
        if installedFonts.contains(where: { $0.name == "Vazir" }) {
            return "Vazir"
        }
        if installedFonts.contains(where: { $0.name == "Vazir Code" }) {
            return "Vazir Code"
        }
        return installedFonts.first?.name
    }

    public init(installedFonts: [PersianFontCandidate], uninstalledFonts: [PersianFontCandidate]) {
        self.installedFonts = installedFonts
        self.uninstalledFonts = uninstalledFonts
    }
}
