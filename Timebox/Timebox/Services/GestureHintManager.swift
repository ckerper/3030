import Foundation

class GestureHintManager: ObservableObject {
    private let defaults = UserDefaults.standard

    // Track how many times user performs each action via menu
    // After a few times, show a hint about the gesture shortcut

    struct HintConfig {
        let action: String
        let gestureDescription: String
        let menuUsageThreshold: Int // show hint after this many menu uses
    }

    static let hints: [HintConfig] = [
        HintConfig(action: "delete", gestureDescription: "Tip: You can also swipe right to delete", menuUsageThreshold: 2),
        HintConfig(action: "moveToBottom", gestureDescription: "Tip: You can also swipe left to move to bottom", menuUsageThreshold: 2),
        HintConfig(action: "moveToTop", gestureDescription: "Tip: You can also double-tap to move to top", menuUsageThreshold: 3),
        HintConfig(action: "edit", gestureDescription: "Tip: You can also double-tap to edit", menuUsageThreshold: 3),
        HintConfig(action: "reorder", gestureDescription: "Tip: You can also touch and hold to drag-reorder", menuUsageThreshold: 2),
    ]

    func recordMenuAction(_ action: String) {
        let key = "gestureHint_\(action)_count"
        let count = defaults.integer(forKey: key) + 1
        defaults.set(count, forKey: key)
    }

    func shouldShowHint(for action: String) -> String? {
        let key = "gestureHint_\(action)_count"
        let count = defaults.integer(forKey: key)

        let dismissedKey = "gestureHint_\(action)_dismissed"
        if defaults.bool(forKey: dismissedKey) { return nil }

        guard let hint = Self.hints.first(where: { $0.action == action }) else { return nil }

        if count >= hint.menuUsageThreshold {
            return hint.gestureDescription
        }
        return nil
    }

    func dismissHint(for action: String) {
        let key = "gestureHint_\(action)_dismissed"
        defaults.set(true, forKey: key)
    }
}
