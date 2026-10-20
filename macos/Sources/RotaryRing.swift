import AppKit

/// Transparent hit area over the physical slide-rule rim. The center remains
/// available for moving the clock, and the photographed pushers remain separate.
@MainActor
final class RotaryRing: NSButton, ScrollRotatingControl {
    var innerRadiusFraction: CGFloat = 0.84
    var hapticMode: HapticMode = .generic
    private let change: (Double) -> Void
    private let haptic: (NSHapticFeedbackManager.FeedbackPattern) -> Void
    private var previousAngle: Double?
    private var hovering = false
    private var area: NSTrackingArea?
    init(hapticFeedback: ((NSHapticFeedbackManager.FeedbackPattern) -> Void)?, change: @escaping (Double) -> Void) {
        self.change = change
        self.haptic = hapticFeedback ?? { NSHapticFeedbackManager.defaultPerformer.perform($0, performanceTime: .now) }
        super.init(frame: .zero)
        title = ""; isBordered = false; focusRingType = .none
        setAccessibilityLabel(L("Slide rule"))
        setAccessibilityCustomActions([
            NSAccessibilityCustomAction(name: L("Rotate scale −1°"), target: self, selector: #selector(left)),
            NSAccessibilityCustomAction(name: L("Rotate scale +1°"), target: self, selector: #selector(right))
        ])
        toolTip = L("Drag or scroll to rotate the slide rule.")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard isEnabled, !isHiddenOrHasHiddenAncestor, let window, !window.ignoresMouseEvents else { return nil }
        return containsInteractionPoint(convert(point, from: superview)) ? self : nil
    }
    private func containsInteractionPoint(_ point: NSPoint) -> Bool {
        guard bounds.width > 0, bounds.height > 0 else { return false }
        let radius = hypot((point.x - bounds.midX) / (bounds.width / 2), (point.y - bounds.midY) / (bounds.height / 2))
        return radius >= innerRadiusFraction && radius <= 1
    }
    private func angle(_ event: NSEvent) -> Double {
        let p = convert(event.locationInWindow, from: nil)
        return atan2(p.x - bounds.midX, p.y - bounds.midY) * 180 / .pi
    }
    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { superview?.rightMouseDown(with: event); return }
        guard window?.ignoresMouseEvents == false else { return }
        previousAngle = angle(event)
    }
    override func mouseDragged(with event: NSEvent) {
        guard let previousAngle else { return }
        let current = angle(event)
        let delta = (current - previousAngle + 540).truncatingRemainder(dividingBy: 360) - 180
        self.previousAngle = current
        change(delta)
    }
    override func mouseUp(with event: NSEvent) { cancelTracking() }
    @discardableResult func rotateFromScroll(_ event: NSEvent) -> Bool {
        guard isEnabled, !isHiddenOrHasHiddenAncestor, window?.ignoresMouseEvents == false else { return false }
        if let delta = RotationScroll.degrees(for: event) { change(delta) }
        return true
    }
    override func scrollWheel(with event: NSEvent) {
        (superview as? ClockView)?.handleRotationScroll(event)
    }
    func cancelTracking() { previousAngle = nil }
    override func rightMouseDown(with event: NSEvent) { superview?.rightMouseDown(with: event) }
    @objc private func left() -> Bool { change(-1); return true }
    @objc private func right() -> Bool { change(1); return true }
    override func draw(_ dirtyRect: NSRect) { }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area { removeTrackingArea(area) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .inVisibleRect, .activeAlways], owner: self)
        self.area = area; addTrackingArea(area)
    }
    override func mouseEntered(with event: NSEvent) { pointerMoved(with: event) }
    override func mouseMoved(with event: NSEvent) { pointerMoved(with: event) }
    override func mouseExited(with event: NSEvent) { endPointerHover() }
    func pointerMoved(with event: NSEvent) {
        guard isEnabled, !isHiddenOrHasHiddenAncestor, window?.ignoresMouseEvents == false,
              containsInteractionPoint(convert(event.locationInWindow, from: nil)) else { endPointerHover(); return }
        NSCursor.pointingHand.set()
        if !hovering { hovering = true; if let pattern = hapticMode.pattern { haptic(pattern) } }
    }
    func endPointerHover() { if hovering { hovering = false; NSCursor.arrow.set() } }
    override var isEnabled: Bool { didSet { if !isEnabled { endPointerHover(); cancelTracking() } } }
    override var isHidden: Bool { didSet { if isHidden { endPointerHover(); cancelTracking() } } }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); endPointerHover(); cancelTracking() }
}
