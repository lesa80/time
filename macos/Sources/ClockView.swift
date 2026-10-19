import AppKit

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
    var onInteraction: ((DialSpecification.MechanicalAction) -> Void)?
    private var mechanicalButtons: [MechanicalButton] = []
    var onDragEnded: (() -> Void)?
    private var dragStart: (pointer: NSPoint, windowOrigin: NSPoint)?
    private var didDrag = false
    private var artworkCache: (size: CGSize, scale: CGFloat, background: CGImage, foreground: CGImage)?

    init(renderer: DialRenderer) {
        self.renderer = renderer
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
        setAccessibilityRole(mechanicalButtons.contains { !$0.isHidden } ? .group : .image)
        setAccessibilityHelp(toolTip)
    }
    private func rebuildMechanicalControls() {
        mechanicalButtons.forEach { $0.removeFromSuperview() }
        mechanicalButtons = (renderer.specification.mechanicalControls ?? []).map { control in
            let button = MechanicalButton(control: control) { [weak self] in self?.onInteraction?(control.action) }
            addSubview(button)
            return button
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
            }
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
            renderer.draw(in: context, size: bounds.size, angles: angles, showSeconds: showSeconds, showBezel: showBezel, pass: .live, chronograph: chronograph)
            context.draw(cache.foreground, in: bounds)
        } else {
            renderer.draw(in: context, size: bounds.size, angles: angles, showSeconds: showSeconds, showBezel: showBezel, chronograph: chronograph)
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
}

/// A real AppKit button over the photographed pusher. Normal artwork stays intact.
@MainActor
final class MechanicalButton: NSButton {
    let control: DialSpecification.MechanicalControl
    private let onPress: () -> Void
    init(control: DialSpecification.MechanicalControl, onPress: @escaping () -> Void) {
        self.control = control
        self.onPress = onPress
        super.init(frame: .zero)
        title = ""
        isBordered = false
        focusRingType = .none
        setButtonType(.momentaryChange)
        target = self
        action = #selector(pressed)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func pressed() { onPress() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { superview?.rightMouseDown(with: event); return }
        super.mouseDown(with: event)
    }
    override func rightMouseDown(with event: NSEvent) { superview?.rightMouseDown(with: event) }
    override func resetCursorRects() {
        if isEnabled { addCursorRect(bounds, cursor: .pointingHand) }
    }
    override func draw(_ dirtyRect: NSRect) {
        if isHighlighted {
            NSColor.white.withAlphaComponent(0.18).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 4, yRadius: 4).fill()
        }
    }
}

@MainActor
final class ClockWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
