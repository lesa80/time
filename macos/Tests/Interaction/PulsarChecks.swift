import AppKit

@MainActor
func checkPulsarInterface(library: ThemeLibrary) throws {
    let pulsarRenderer = try library.renderer(for: "hamilton-pulsar")
    let suite = "local.vremya.pulsar-tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.set(280, forKey: "diameter")
    defaults.set(true, forKey: "showBezel")
    var now: TimeInterval = 0
    let delegate = AppDelegate(library: library, renderer: pulsarRenderer, defaults: defaults,
                               signalSound: {}, buttonSound: { _ in })
    delegate.pulsar = Pulsar(now: { now })
    let window = ClockWindow(contentRect: NSRect(origin: .zero, size: pulsarRenderer.displaySize(width: 280, showBezel: true)),
                             styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    let view = ClockView(renderer: pulsarRenderer, hapticFeedback: { _ in })
    delegate.window = window; delegate.clockView = view; window.contentView = view
    view.onInteraction = { [weak delegate] in delegate?.performInteraction($0) }
    defer {
        view.onInteraction = nil; view.cancelMechanicalPresses(); view.endPointerHover()
        delegate.timer?.invalidate(); delegate.gshockServiceTimer?.invalidate()
        defaults.removePersistentDomain(forName: suite)
        window.close()
    }
    let menu = delegate.makeClockMenu()
    delegate.menuNeedsUpdate(menu)
    let angles = HandAngles(hours: 10, minutes: 10, seconds: 30, hourCycle: 12)
    let later = HandAngles(hours: 16, minutes: 40, seconds: 50, hourCycle: 12)
    let output = URL(fileURLWithPath: "macos/.build/previews")
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    func pixels(_ renderer: DialRenderer, angles: HandAngles, led: PulsarReading? = nil, bezel: Bool = true) -> [UInt8] {
        let size = renderer.displaySize(width: 220, showBezel: bezel)
        let bitmap = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
            bytesPerRow: Int(size.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        renderer.draw(in: bitmap, size: size, angles: angles, showBezel: bezel, pulsar: led)
        return Array(UnsafeBufferPointer(start: bitmap.data!.assumingMemoryBound(to: UInt8.self), count: Int(size.width * size.height) * 4))
    }
    let selection = NSMenuItem()
    let actions = delegate.menuActions["pulsarTime"]!.menu!
    expect(!delegate.pulsar.reading.isLit && delegate.menuActions["pulsarTime"]?.isHidden == false &&
           delegate.menuActions["gshockA"]?.isHidden == true, "Pulsar must begin with its display off and its own menu")
    view.showBezel = true
    window.setContentSize(pulsarRenderer.displaySize(width: 280, showBezel: true)); view.layoutSubtreeIfNeeded()
    let button = view.subviews.compactMap { $0 as? MechanicalButton }.first!
    func pointer(_ type: NSEvent.EventType, _ point: NSPoint) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                           context: nil, eventNumber: 0, clickCount: 1, pressure: 0)!
    }
    let point = button.convert(NSPoint(x: button.bounds.midX, y: button.bounds.midY), to: nil)
    button.mouseDown(with: pointer(.leftMouseDown, point))
    expect(delegate.pulsar.reading.mode == .time, "Pulsar must light immediately on press, without waiting for release")
    now += 1.3; delegate.updateClock()
    expect(view.pulsarDisplay.mode == .seconds, "Holding the real pusher must switch to live seconds")
    button.mouseUp(with: pointer(.leftMouseUp, point))
    expect(!delegate.pulsar.reading.isLit, "Releasing a long press must turn off the LED without restarting a short press")
    button.mouseDown(with: pointer(.leftMouseDown, point)); now += 0.1
    button.mouseUp(with: pointer(.leftMouseUp, point))
    expect(delegate.pulsar.reading.mode == .time, "A short press must keep time visible for the remaining timeout")
    now += 1.2; delegate.updateClock()
    expect(!view.pulsarDisplay.isLit, "The live display must turn itself off after 1.25 seconds")
    button.mouseDown(with: pointer(.leftMouseDown, point))
    button.mouseDragged(with: pointer(.leftMouseDragged, NSPoint(x: point.x + 500, y: point.y)))
    button.mouseUp(with: pointer(.leftMouseUp, point))
    expect(!delegate.pulsar.reading.isLit, "Dragging away must cancel illumination")
    button.mouseDown(with: pointer(.leftMouseDown, point)); window.ignoresMouseEvents = true
    expect(!delegate.pulsar.reading.isLit, "Locking the window during a hold must release the electronic pusher")
    window.ignoresMouseEvents = false
    button.mouseDown(with: pointer(.leftMouseDown, point)); view.showBezel = false
    expect(!delegate.pulsar.reading.isLit && button.isHidden, "Hiding the case must cancel a held pusher")
    let timeAction = delegate.menuActions["pulsarTime"]!
    actions.performActionForItem(at: actions.index(of: timeAction))
    expect(delegate.pulsar.reading.mode == .time, "The time menu action must work without the case")
    let secondsAction = delegate.menuActions["pulsarSeconds"]!
    actions.performActionForItem(at: actions.index(of: secondsAction))
    expect(delegate.pulsar.reading.mode == .seconds, "The seconds menu action must illuminate its own reading")
    let offAction = delegate.menuActions["pulsarOff"]!
    actions.performActionForItem(at: actions.index(of: offAction))
    expect(!delegate.pulsar.reading.isLit, "The off menu command must extinguish the LED")
    delegate.illuminatePulsar(); delegate.pauseForSleep()
    expect(!delegate.pulsar.reading.isLit, "Sleep must not leave a held or timed LED display latched")
    delegate.wakeFromSleep()
    delegate.illuminatePulsar(); selection.representedObject = "minimalism"; delegate.selectTheme(selection)
    expect(!delegate.pulsar.reading.isLit, "Changing theme must discard any pending Pulsar illumination")
    for mode in [PulsarReading.Mode.off, .time, .seconds] {
        let name = mode == .off ? "off" : mode == .time ? "time" : "seconds"
        try pulsarRenderer.png(side: 360, angles: angles, pulsar: PulsarReading(mode: mode)).write(to: output.appendingPathComponent("pulsar-\(name).png"))
    }
    let off = pixels(pulsarRenderer, angles: angles, led: PulsarReading())
    expect(off == pixels(pulsarRenderer, angles: later, led: PulsarReading()), "No live digits may leak through the unlit ruby crystal")
    let lit = pixels(pulsarRenderer, angles: angles, led: PulsarReading(mode: .time))
    let seconds = pixels(pulsarRenderer, angles: angles, led: PulsarReading(mode: .seconds))
    expect(lit != off && seconds != off && lit != seconds, "Time, seconds and blank crystal must render differently")
    let glass = pulsarRenderer.specification.dialBounds!
    let midline = glass[1] + glass[3] / 2
    let ledHeight = off.count / 4 / 220
    var timeChanges = 0, secondChanges = 0
    for row in 0..<ledHeight {
        let authorY = Double(row) / Double(ledHeight) * pulsarRenderer.specification.resolution[1]
        for column in 0..<220 {
            let offset = (row * 220 + column) * 4
            let range = offset..<offset + 4
            if lit[range] != off[range] {
                timeChanges += 1
                expect(authorY < midline, "P1 hours and minutes must light only the upper row")
            }
            if seconds[range] != off[range] {
                secondChanges += 1
                expect(authorY > midline, "P1 seconds must light only the independent lower pair")
            }
        }
    }
    expect(timeChanges > 10 && secondChanges > 10, "Both physical LED rows must visibly illuminate")
    print("Passed: Pulsar real press/hold/release, timeout, cancellation, menu, sleep and theme cleanup")
}
