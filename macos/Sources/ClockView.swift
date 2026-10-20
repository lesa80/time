import AppKit

enum HapticMode: String, CaseIterable {
    case disabled, generic, alignment, levelChange

    var title: String {
        switch self {
        case .disabled: L("Disabled")
        case .generic: L("Generic")
        case .alignment: L("Alignment")
        case .levelChange: L("Level change")
        }
    }
    var pattern: NSHapticFeedbackManager.FeedbackPattern? {
        switch self {
        case .disabled: nil
        case .generic: .generic
        case .alignment: .alignment
        case .levelChange: .levelChange
        }
    }
}

@MainActor
final class ClockView: NSView {
    var renderer: DialRenderer { didSet { invalidateArtwork(); rebuildMechanicalControls(); updateThemeDescription() } }
    var showSeconds = true
    var showBezel = true { didSet { invalidateArtwork(); layoutMechanicalControls(); updateThemeDescription() } }
    var clockMenu: NSMenu?
    var date = Date()
    var chronograph = ChronographReading() {
        didSet { if (oldValue.elapsed > 0) != (chronograph.elapsed > 0) { updateMechanicalControls() } }
    }
    var chronographIsRunning = false {
        didSet { if oldValue != chronographIsRunning { updateMechanicalControls() } }
    }
    var heritage = HeritageReading()
    var onRotation: ((Double) -> Void)?
    private var rotaryRing: RotaryRing?
    var onInteraction: ((DialSpecification.MechanicalAction) -> Void)?
    var gshockDisplay: GShockDisplay?
    var pulsarDisplay = PulsarReading()
    var hapticMode: HapticMode = .generic {
        didSet { mechanicalButtons.forEach { $0.hapticMode = hapticMode }; rotaryRing?.hapticMode = hapticMode }
    }
    private var mechanicalButtons: [MechanicalButton] = []
    private let hapticFeedback: ((NSHapticFeedbackManager.FeedbackPattern) -> Void)?
    var onDragEnded: (() -> Void)?
    private var dragStart: (pointer: NSPoint, windowOrigin: NSPoint)?
    private var didDrag = false
    private var artworkCache: (size: CGSize, scale: CGFloat, background: CGImage, foreground: CGImage)?

    init(renderer: DialRenderer, hapticFeedback: ((NSHapticFeedbackManager.FeedbackPattern) -> Void)? = nil) {
        self.renderer = renderer
        self.hapticFeedback = hapticFeedback
        super.init(frame: .zero)
        setAccessibilityElement(true)
        rebuildMechanicalControls()
        updateThemeDescription()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func updateThemeDescription() {
        if renderer.specification.displayMode == "digital" {
            setAccessibilityLabel(L("%@ · %@, digital clock", L("Vremya"), renderer.theme.localizedTitle))
            toolTip = L("Digital clock with local time and date. Drag to move. Right-click for settings.")
        } else {
            setAccessibilityLabel(L("%@ · %@, %ld-hour dial", L("Vremya"), renderer.theme.localizedTitle, renderer.theme.hourCycle))
            toolTip = L("Drag to move. Right-click for settings. One hour-hand revolution takes %ld hours.", renderer.theme.hourCycle)
        }
        if renderer.hasChronograph {
            toolTip = L("Upper pusher: start/pause. Lower pusher: reset. Running seconds are at 9. Right-click → Interaction for all controls.")
        }
        if renderer.isChronostop { toolTip = L("Press to start. Press and hold to read; release to reset. Right-click → Interaction for controls.") }
        if renderer.isParking { toolTip = L("Drag the upper crown vertically or scroll to set the alarm disc. Click it to arm or cancel. Right-click → Interaction for reminders.") }
        if renderer.isNavitimer { toolTip = L("Drag or scroll the outer scale to calculate. Upper pusher starts/pauses the chronograph; lower pusher resets it.") }
        if renderer.isGShock {
            toolTip = L("A: adjust/split/reset. B: start/stop. C: mode. D: light. Hold B in Timekeeping for Flash Alert. Right-click → Interaction for settings.")
        }
        if renderer.isPulsar { toolTip = L("Press the front button to show time. Keep holding to show seconds. Right-click → Interaction for controls.") }
        setAccessibilityRole(rotaryRing != nil || mechanicalButtons.contains { !$0.isHidden } ? .group : .image)
        setAccessibilityHelp(toolTip)
    }
    private func rebuildMechanicalControls() {
        mechanicalButtons.forEach { $0.removeFromSuperview() }
        rotaryRing?.removeFromSuperview(); rotaryRing = nil
        mechanicalButtons = (renderer.specification.mechanicalControls ?? []).map { control in
            let button = MechanicalButton(control: control, hapticFeedback: hapticFeedback) { [weak self] in self?.onInteraction?(control.action) }
            if let action = control.longAction {
                button.onLongPress = { [weak self] in self?.onInteraction?(action) }
            }
            if control.action == .pulsarLight {
                button.onPressBegan = { [weak self] in self?.onInteraction?(.pulsarPress) }
                button.onPressEnded = { [weak self] in self?.onInteraction?(.pulsarRelease) }
                button.onPressCancelled = { [weak self] in self?.onInteraction?(.pulsarCancel) }
            }
            if control.action == .chronostop {
                button.onPressBegan = { [weak self] in self?.onInteraction?(.chronostopPress) }
                button.onPressEnded = { [weak self] in self?.onInteraction?(.chronostopRelease) }
                button.onPressCancelled = { [weak self] in self?.onInteraction?(.chronostopRelease) }
            }
            if control.action == .parkingCrown { button.onRotationDelta = { [weak self] in self?.onRotation?($0) } }
            button.hapticMode = hapticMode
            addSubview(button)
            return button
        }
        if renderer.isNavitimer {
            let ring = RotaryRing(hapticFeedback: hapticFeedback) { [weak self] in self?.onRotation?($0) }
            ring.hapticMode = hapticMode; addSubview(ring); rotaryRing = ring
        }
        layoutMechanicalControls()
        updateMechanicalControls()
    }
    override func layout() {
        super.layout()
        layoutMechanicalControls()
    }
    private func layoutMechanicalControls() {
        let resolution = renderer.specification.resolution
        if let ring = rotaryRing, let b = renderer.specification.dialBounds {
            // The live scale stays usable in both full-watch and dial-only views.
            if showBezel {
                let dial = NSRect(x: b[0] / resolution[0] * bounds.width, y: (1 - (b[1] + b[3]) / resolution[1]) * bounds.height,
                    width: b[2] / resolution[0] * bounds.width, height: b[3] / resolution[1] * bounds.height)
                // Include the physical beaded metal rim, just outside the glass.
                ring.frame = dial.insetBy(dx: -dial.width * 0.025, dy: -dial.height * 0.025)
                ring.innerRadiusFraction = 0.84 / 1.05
            } else { ring.frame = bounds; ring.innerRadiusFraction = 0.84 }
        }
        for button in mechanicalButtons {
            let b = button.control.bounds
            button.frame = NSRect(x: b[0] / resolution[0] * bounds.width,
                                  y: (1 - (b[1] + b[3]) / resolution[1]) * bounds.height,
                                  width: b[2] / resolution[0] * bounds.width,
                                  height: b[3] / resolution[1] * bounds.height)
            button.isHidden = !showBezel || !renderer.hasBezel
        }
    }
    private func updateMechanicalControls() {
        for button in mechanicalButtons {
            let label: String
            switch button.control.action {
            case .chronographToggle:
                label = chronographIsRunning ? L("Pause chronograph") : chronograph.elapsed > 0 ? L("Resume chronograph") : L("Start chronograph")
                button.toolTip = L("Upper pusher: start, pause or resume the chronograph.")
            case .chronographReset:
                label = L("Reset chronograph")
                button.isEnabled = chronographIsRunning || chronograph.elapsed > 0
                button.toolTip = L("Lower pusher: stop and reset the chronograph.")
            case .gshockA: label = L("A · Adjust / split / reset")
            case .gshockB:
                label = L("B · Start / stop / increment")
                button.toolTip = L("Hold for two seconds in Timekeeping to toggle Flash Alert.")
            case .gshockC: label = L("C · Mode / next field")
            case .gshockD: label = L("D · Light / format / auto-repeat")
            case .gshockFlash: label = L("Flash Alert")
            case .chronostop, .chronostopPress, .chronostopRelease:
                label = L("Press to start; hold to read; release to reset.")
            case .parkingCrown:
                label = L("Parking alarm crown")
                button.toolTip = L("Drag vertically or scroll to rotate the alarm disc. Click to arm or cancel.")
            case .pulsarLight:
                label = L("Show time")
                button.toolTip = L("Press to show time; keep holding to show seconds.")
            case .pulsarSeconds: label = L("Show seconds")
            case .pulsarPress, .pulsarRelease, .pulsarCancel: label = L("Show time")
            }
            if button.toolTip == nil { button.toolTip = label }
            button.setAccessibilityLabel(label)
        }
    }
    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        if !(showBezel && renderer.hasBezel) && renderer.specification.dialShape != "rectangle" {
            let r = bounds.width / 2
            guard hypot(local.x - bounds.midX, local.y - bounds.midY) <= r else { return nil }
        }
        return super.hitTest(point)
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.clear(bounds)
        let angles = HandAngles(date: date, hourCycle: renderer.theme.hourCycle, direction: renderer.theme.rotationDirection)
        let scale = window?.backingScaleFactor ?? 1
        if artworkCache?.size != bounds.size || artworkCache?.scale != scale {
            artworkCache = makeArtworkCache(scale: scale)
        }
        if let cache = artworkCache {
            context.draw(cache.background, in: bounds)
            renderer.draw(in: context, size: bounds.size, angles: angles, showSeconds: showSeconds, showBezel: showBezel, pass: .live, chronograph: chronograph, gshock: gshockDisplay, pulsar: renderer.isPulsar ? pulsarDisplay : nil, heritage: heritage)
            context.draw(cache.foreground, in: bounds)
        } else {
            renderer.draw(in: context, size: bounds.size, angles: angles, showSeconds: showSeconds, showBezel: showBezel, chronograph: chronograph, gshock: gshockDisplay, pulsar: renderer.isPulsar ? pulsarDisplay : nil, heritage: heritage)
        }
    }
    private func invalidateArtwork() {
        artworkCache = nil
        needsDisplay = true
    }
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        invalidateArtwork()
    }
    private func makeArtworkCache(scale: CGFloat) -> (size: CGSize, scale: CGFloat, background: CGImage, foreground: CGImage)? {
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        func image(pass: DialRenderer.DrawingPass) -> CGImage? {
            let width = Int(ceil(bounds.width * scale)), height = Int(ceil(bounds.height * scale))
            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
                  let bitmap = CGContext(data: nil, width: width, height: height,
                      bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace,
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            // Preserve alignment when a tall watch is fitted to a fractional-point width.
            bitmap.scaleBy(x: CGFloat(width) / bounds.width, y: CGFloat(height) / bounds.height)
            renderer.draw(in: bitmap, size: bounds.size, angles: HandAngles(hours: 0, minutes: 0, seconds: 0),
                          showBezel: showBezel, pass: pass)
            return bitmap.makeImage()
        }
        guard let background = image(pass: .background), let foreground = image(pass: .foreground) else { return nil }
        return (bounds.size, scale, background, foreground)
    }
    override func mouseDown(with event: NSEvent) {
        dragStart = nil
        didDrag = false
        if event.modifierFlags.contains(.control) {
            rightMouseDown(with: event)
            return
        }
        guard let window else { return }
        dragStart = (window.convertPoint(toScreen: event.locationInWindow), window.frame.origin)
    }
    override func mouseDragged(with event: NSEvent) {
        guard let window, let start = dragStart else { return }
        let point = window.convertPoint(toScreen: event.locationInWindow)
        let dx = point.x - start.pointer.x, dy = point.y - start.pointer.y
        // Once a drag crosses the threshold, returning to the start is still a drag.
        guard didDrag || hypot(dx, dy) >= 4 else { return }
        didDrag = true
        window.setFrameOrigin(NSPoint(x: start.windowOrigin.x + dx, y: start.windowOrigin.y + dy))
    }
    override func mouseUp(with event: NSEvent) {
        defer { dragStart = nil; didDrag = false }
        if didDrag { onDragEnded?() }
    }
    override func rightMouseDown(with event: NSEvent) {
        if let clockMenu { NSMenu.popUpContextMenu(clockMenu, with: event, for: self) }
    }
    /// Does not activate the desktop window or intercept scrolling in About/settings.
    @discardableResult func handleRotationScroll(_ event: NSEvent) -> Bool {
        guard event.type == .scrollWheel, !isHiddenOrHasHiddenAncestor,
              let window, !window.ignoresMouseEvents else { return false }
        // A CGEvent-backed event with no window uses Cocoa screen coordinates.
        let pointInWindow = event.window === window ? event.locationInWindow : window.convertPoint(fromScreen: event.locationInWindow)
        let point = superview?.convert(pointInWindow, from: nil) ?? pointInWindow
        guard let control = hitTest(point) as? any ScrollRotatingControl else { return false }
        return control.rotateFromScroll(event)
    }
    override func scrollWheel(with event: NSEvent) { handleRotationScroll(event) }
    func pointerMoved(with event: NSEvent) {
        // A non-key window cannot rely on normal button cursor rectangles.
        let point = superview?.convert(event.locationInWindow, from: nil) ?? event.locationInWindow
        if let ring = hitTest(point) as? RotaryRing {
            mechanicalButtons.forEach { $0.endPointerHover() }
            ring.pointerMoved(with: event); return
        }
        rotaryRing?.endPointerHover()
        let target = hitTest(point) as? MechanicalButton
        mechanicalButtons.filter { $0 !== target }.forEach { $0.endPointerHover() }
        target?.mouseMoved(with: event)
    }
    func endPointerHover() {
        mechanicalButtons.forEach { $0.endPointerHover() }; rotaryRing?.endPointerHover()
    }
    func cancelMechanicalPresses() { mechanicalButtons.forEach { $0.cancelPressTracking() }; rotaryRing?.cancelTracking() }
}

/// A real AppKit button over the photographed pusher. Normal artwork stays intact.
@MainActor
final class MechanicalButton: NSButton, ScrollRotatingControl {
    let control: DialSpecification.MechanicalControl
    private let onPress: () -> Void
    var hapticMode: HapticMode = .generic
    private let hapticFeedback: (NSHapticFeedbackManager.FeedbackPattern) -> Void
    private var hoverTrackingArea: NSTrackingArea?
    private var pointerInside = false
    var onLongPress: (() -> Void)? {
        didSet {
            setAccessibilityCustomActions(onLongPress == nil ? [] : [
                NSAccessibilityCustomAction(name: control.longAction == .pulsarSeconds ? L("Show seconds") : L("Flash Alert"), target: self, selector: #selector(accessibilityLongPress))
            ])
        }
    }
    var onRotationDelta: ((Double) -> Void)?
    private var rotationPoint: NSPoint?
    private var didRotate = false
    var onPressBegan: (() -> Void)?
    var onPressEnded: (() -> Void)?
    var onPressCancelled: (() -> Void)?
    private var longPressTimer: Timer?
    private var trackingLongPress = false
    private var longPressFired = false
    private var pressCancelled = false

    init(control: DialSpecification.MechanicalControl, hapticFeedback: ((NSHapticFeedbackManager.FeedbackPattern) -> Void)? = nil,
         onPress: @escaping () -> Void) {
        self.control = control
        self.onPress = onPress
        self.hapticFeedback = hapticFeedback ?? { pattern in
            // Resolve the performer per gesture so macOS can honor the input device and preferences.
            NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
        }
        super.init(frame: .zero)
        title = ""
        isBordered = false
        focusRingType = .none
        setButtonType(.momentaryChange)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        target = self
        action = #selector(pressed)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func pressed() { onPress() }
    @objc private func accessibilityLongPress() -> Bool {
        guard isEnabled, !isHiddenOrHasHiddenAncestor, window?.ignoresMouseEvents == false,
              let onLongPress else { return false }
        onLongPress()
        return true
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { superview?.rightMouseDown(with: event); return }
        if onRotationDelta != nil {
            guard isEnabled, !isHiddenOrHasHiddenAncestor, window?.ignoresMouseEvents == false else { return }
            rotationPoint = event.locationInWindow; didRotate = false; return
        }
        guard onLongPress != nil || onPressBegan != nil else { super.mouseDown(with: event); return }
        guard isEnabled, !isHiddenOrHasHiddenAncestor, window?.ignoresMouseEvents == false else { return }
        cancelLongPress()
        trackingLongPress = true
        longPressFired = false
        pressCancelled = false
        if let onPressBegan { onPressBegan(); return }
        let timer = Timer(timeInterval: 2, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.trackingLongPress, !self.pressCancelled, self.isEnabled,
                      !self.isHiddenOrHasHiddenAncestor, self.window?.ignoresMouseEvents == false else { return }
                self.longPressFired = true
                self.onLongPress?()
            }
        }
        longPressTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    override func mouseDragged(with event: NSEvent) {
        if let start = rotationPoint, let onRotationDelta {
            let delta = event.locationInWindow.y - start.y
            if didRotate || abs(delta) >= 3 { didRotate = true; rotationPoint = event.locationInWindow; onRotationDelta(-delta * 0.5) }
            return
        }
        guard trackingLongPress else { super.mouseDragged(with: event); return }
        if !bounds.contains(convert(event.locationInWindow, from: nil)) {
            if !pressCancelled { onPressCancelled?() }
            pressCancelled = true
            longPressTimer?.invalidate()
        }
    }
    override func mouseUp(with event: NSEvent) {
        if rotationPoint != nil {
            rotationPoint = nil
            if !didRotate && bounds.contains(convert(event.locationInWindow, from: nil)) { performClick(nil) }
            return
        }
        guard trackingLongPress else { super.mouseUp(with: event); return }
        let fire = !longPressFired && !pressCancelled && isEnabled && !isHiddenOrHasHiddenAncestor &&
            window?.ignoresMouseEvents == false && bounds.contains(convert(event.locationInWindow, from: nil))
        if onPressBegan != nil {
            if fire { onPressEnded?() } else if !pressCancelled { onPressCancelled?() }
            pressCancelled = true
            cancelLongPress()
            return
        }
        cancelLongPress()
        if fire { performClick(nil) }
    }
    @discardableResult func rotateFromScroll(_ event: NSEvent) -> Bool {
        guard let onRotationDelta, isEnabled, !isHiddenOrHasHiddenAncestor,
              window?.ignoresMouseEvents == false else { return false }
        if let delta = RotationScroll.degrees(for: event) { onRotationDelta(delta) }
        return true
    }
    override func scrollWheel(with event: NSEvent) {
        (superview as? ClockView)?.handleRotationScroll(event)
    }
    private func cancelLongPress() {
        rotationPoint = nil; didRotate = false
        if trackingLongPress && !pressCancelled { onPressCancelled?() }
        longPressTimer?.invalidate()
        longPressTimer = nil
        trackingLongPress = false
    }
    func cancelPressTracking() { cancelLongPress() }
    override func rightMouseDown(with event: NSEvent) { superview?.rightMouseDown(with: event) }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea { removeTrackingArea(hoverTrackingArea) }
        // The desktop clock never becomes key; hover must also work while another app is active.
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .inVisibleRect, .activeAlways],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverTrackingArea = area
    }
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        beginPointerHover()
    }
    override func mouseMoved(with event: NSEvent) {
        // Also recover if AppKit did not deliver the initial entered event.
        beginPointerHover()
    }
    private func beginPointerHover() {
        guard isEnabled, !isHiddenOrHasHiddenAncestor, let window, !window.ignoresMouseEvents else {
            endPointerHover()
            return
        }
        NSCursor.pointingHand.set()
        guard !pointerInside else { return }
        pointerInside = true
        if let pattern = hapticMode.pattern { hapticFeedback(pattern) }
    }
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        endPointerHover()
    }
    func endPointerHover() {
        let wasInside = pointerInside
        pointerInside = false
        if wasInside && NSCursor.current == .pointingHand { NSCursor.arrow.set() }
    }
    override var isEnabled: Bool {
        didSet { if !isEnabled { endPointerHover(); cancelLongPress() } }
    }
    override var isHidden: Bool {
        didSet { if isHidden { endPointerHover(); cancelLongPress() } }
    }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        endPointerHover()
        cancelLongPress()
    }
    override var isOpaque: Bool { false }
    // Only the parent draws the photographed case. Press/hover must not paint over it.
    override func draw(_ dirtyRect: NSRect) { }
}

@MainActor
final class ClockWindow: NSWindow {
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask,
                  backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        acceptsMouseMovedEvents = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func sendEvent(_ event: NSEvent) {
        if event.type == .scrollWheel, let view = contentView as? ClockView {
            // Accessory windows never become key. Route directly to the hovered
            // rotary part, without activating the app or retaining a gesture target.
            view.handleRotationScroll(event)
            return
        }
        super.sendEvent(event)
        if event.type == .mouseMoved { (contentView as? ClockView)?.pointerMoved(with: event) }
    }
    override var ignoresMouseEvents: Bool {
        didSet {
            if ignoresMouseEvents {
                (contentView as? ClockView)?.endPointerHover()
                (contentView as? ClockView)?.cancelMechanicalPresses()
            }
        }
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
