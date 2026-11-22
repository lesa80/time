import AppKit

/// Shared by crowns and rotating bezels. The window resolves the control under
/// the pointer on each event, so AppKit's scroll-gesture target cannot stay latched
/// to a different mechanical part when the pointer moves.
@MainActor
protocol ScrollRotatingControl: AnyObject {
    @discardableResult func rotateFromScroll(_ event: NSEvent) -> Bool
}

/// Each crown or bezel keeps its own unfinished movement during a gesture.
struct RotationGesture {
    let step: Double?
    private var remainder = 0.0

    init(step: Double?) { self.step = step }

    mutating func reset() { remainder = 0 }

    mutating func consume(_ degrees: Double) -> Double? {
        guard degrees.isFinite, degrees != 0 else { return nil }
        guard let step else { return degrees }
        remainder += degrees
        let movement = (remainder / step).rounded(.towardZero) * step
        remainder -= movement
        return movement != 0 ? movement : nil
    }

    mutating func scroll(_ event: NSEvent) -> Double? {
        if !event.phase.intersection([.mayBegin, .began, .ended, .cancelled]).isEmpty { reset() }
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
        if !precise, let step {
            reset()
            let notches = max(1, abs(delta).rounded())
            return (delta > 0 ? -notches : notches) * step
        }
        return consume(-delta * (precise ? 0.5 : 3))
    }
}
