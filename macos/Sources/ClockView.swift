import AppKit

@MainActor
final class ClockView: NSView {
    var renderer: DialRenderer { didSet { invalidateArtwork(); updateThemeDescription() } }
    var showSeconds = true
    var showBezel = true { didSet { invalidateArtwork() } }
    var clockMenu: NSMenu?
    var date = Date()
    var onToggleBezel: (() -> Void)?
    var onDragEnded: (() -> Void)?
    private var dragStart: (pointer: NSPoint, windowOrigin: NSPoint)?
    private var didDrag = false
    private var artworkCache: (size: CGSize, scale: CGFloat, background: CGImage, foreground: CGImage)?

    init(renderer: DialRenderer) {
        self.renderer = renderer
        super.init(frame: .zero)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityHelp("Нажмите, чтобы показать или скрыть безель и ремешок. Перетащите, чтобы переместить часы.")
        updateThemeDescription()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func updateThemeDescription() {
        setAccessibilityLabel("Время · \(renderer.theme.title), \(renderer.theme.hourCycle)-часовой циферблат")
        setAccessibilityRole(renderer.hasBezel ? .button : .image)
        let clickHelp = renderer.hasBezel ? "Клик — безель и ремешок. " : ""
        setAccessibilityHelp(clickHelp + "Перетащите, чтобы переместить часы. Правый клик — настройки.")
        toolTip = clickHelp + " Перетаскивание — переместить часы. Правый клик — настройки. Полный оборот часовой стрелки — \(renderer.theme.hourCycle) часов."
    }
    override var isOpaque: Bool { false }
    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? {
        if (showBezel && renderer.hasBezel) || renderer.specification.dialShape == "rectangle" { return bounds.contains(point) ? self : nil }
        let r = bounds.width / 2
        return hypot(point.x - r, point.y - r) <= r ? self : nil
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
            renderer.draw(in: context, size: bounds.size, angles: angles, showSeconds: showSeconds, showBezel: showBezel, pass: .hands)
            context.draw(cache.foreground, in: bounds)
        } else {
            renderer.draw(in: context, size: bounds.size, angles: angles, showSeconds: showSeconds, showBezel: showBezel)
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
        if didDrag { onDragEnded?(); return }
        guard let window, let start = dragStart, !didDrag else { return }
        let point = window.convertPoint(toScreen: event.locationInWindow)
        guard hypot(point.x - start.pointer.x, point.y - start.pointer.y) < 4,
              hitTest(convert(event.locationInWindow, from: nil)) != nil else { return }
        onToggleBezel?()
    }
    override func accessibilityPerformPress() -> Bool {
        guard renderer.hasBezel, let onToggleBezel else { return false }
        onToggleBezel()
        return true
    }
    override func rightMouseDown(with event: NSEvent) {
        if let clockMenu { NSMenu.popUpContextMenu(clockMenu, with: event, for: self) }
    }
}

@MainActor
final class ClockWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
