import SwiftUI

public enum NavigationSection: String, CaseIterable, Identifiable, Hashable {
    case general = "General"
    case typography = "Typography"
    case persian = "Persian"
    case appearance = "Appearance"
    case window = "Window"
    case shell = "Shell"
    case config = "Config"

    public var id: String { rawValue }

    public var title: String { rawValue }

    public var iconName: String {
        switch self {
        case .general:
            return "gearshape"
        case .typography:
            return "textformat"
        case .persian:
            return "character.textbox"
        case .appearance:
            return "paintpalette"
        case .window:
            return "macwindow"
        case .shell:
            return "terminal"
        case .config:
            return "doc.text"
        }
    }
}
