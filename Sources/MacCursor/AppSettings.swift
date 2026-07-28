import Cocoa

/// Scales every cursor relative to the per-cursor size declared in the asset
/// manifest, so the artwork keeps its intended proportions at every setting.
enum CursorSize: String, CaseIterable {
    case small, medium, large

    var multiplier: CGFloat {
        switch self {
        case .small: return 0.77
        case .medium: return 1.0
        case .large: return 1.28
        }
    }

    var title: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}

final class AppSettings {
    static let shared = AppSettings()

    private enum Key {
        static let enabled = "cursorEnabled"
        static let size = "cursorSize"
        static let clickReaction = "clickReactionEnabled"
        static let shapeSwitching = "shapeSwitchingEnabled"
    }

    private let defaults = UserDefaults.standard

    /// Fired after any setting changes so the overlay can react.
    var onChange: (() -> Void)?

    private init() {
        defaults.register(defaults: [
            Key.enabled: true,
            Key.size: CursorSize.medium.rawValue,
            Key.clickReaction: true,
            Key.shapeSwitching: true,
        ])
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: Key.enabled) }
        set { defaults.set(newValue, forKey: Key.enabled); onChange?() }
    }

    var size: CursorSize {
        get { CursorSize(rawValue: defaults.string(forKey: Key.size) ?? "") ?? .medium }
        set { defaults.set(newValue.rawValue, forKey: Key.size); onChange?() }
    }

    var clickReactionEnabled: Bool {
        get { defaults.bool(forKey: Key.clickReaction) }
        set { defaults.set(newValue, forKey: Key.clickReaction); onChange?() }
    }

    /// Follow the system cursor's shape (text, resize, and so on) rather than
    /// showing the idle cat everywhere.
    var shapeSwitchingEnabled: Bool {
        get { defaults.bool(forKey: Key.shapeSwitching) }
        set { defaults.set(newValue, forKey: Key.shapeSwitching); onChange?() }
    }
}
