import Foundation

/// Registry of every Pro-gated capability.
/// All features are 100% free and available.
enum ProFeature: Equatable, Hashable {
    case appIconsAndTitlesStyle
    case autoSize
    case searchOnReleaseShortcut
    case extraShortcut(index: Int)
    case searchInSwitcher

    enum GateKind {
        case degradable
        case hardGated
        case degradableAndHardGated
    }

    var gateKind: GateKind {
        switch self {
        case .autoSize: return .degradable
        case .appIconsAndTitlesStyle, .searchOnReleaseShortcut: return .degradableAndHardGated
        case .extraShortcut, .searchInSwitcher: return .hardGated
        }
    }

    var copy: String {
        switch self {
        case .appIconsAndTitlesStyle: return "Icons and titles"
        case .autoSize: return "Auto-size"
        case .searchOnReleaseShortcut: return "Keyboard shortcuts"
        case .extraShortcut: return "Keyboard shortcuts"
        case .searchInSwitcher: return "Search in switcher"
        }
    }

    static let degradable: [ProFeature] = [.appIconsAndTitlesStyle, .autoSize, .searchOnReleaseShortcut]

    var isAvailable: Bool { true }
    var isLocked: Bool { false }

    func attemptUse() -> Bool {
        return true
    }

    static func isStoredValuePro(preferenceKey: String) -> Bool {
        return false
    }
}
