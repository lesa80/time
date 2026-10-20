import AppKit

/// Shared by crowns and rotating bezels. The window resolves the control under
/// the pointer on each event, so AppKit's scroll-gesture target cannot stay latched
/// to a different mechanical part when the pointer moves.
@MainActor
protocol ScrollRotatingControl: AnyObject {
    @discardableResult func rotateFromScroll(_ event: NSEvent) -> Bool
}

enum RotationScroll {
    static func degrees(for event: NSEvent) -> Double? {
        guard event.type == .scrollWheel, event.momentumPhase.isEmpty,
              event.phase.intersection([.ended, .cancelled]).isEmpty else { return nil }
        // AppKit has already applied the user's Natural Scrolling preference.
        // Preserve high-resolution trackpad deltas, including sub-degree motion.
        let precise = event.hasPreciseScrollingDeltas
        let x = precise ? event.scrollingDeltaX : event.deltaX
        let y = precise ? event.scrollingDeltaY : event.deltaY
        guard x.isFinite, y.isFinite else { return nil }
        let delta = abs(x) > abs(y) ? x : y
        guard delta != 0 else { return nil }
        return -delta * (precise ? 0.5 : 3)
    }
}
