import AppKit

@MainActor
func checkHeritageInterface(library: ThemeLibrary) throws {
    let suite = "local.vremya.heritage-tests.\(UUID().uuidString)"
    let preferences = UserDefaults(suiteName: suite)!
    preferences.set(280, forKey: "diameter"); preferences.set(true, forKey: "showBezel")
    let renderer = try library.renderer(for: "omega-chronostop")
    let delegate = AppDelegate(library: library, renderer: renderer, defaults: preferences, signalSound: {}, buttonSound: { _ in })
    let window = ClockWindow(contentRect: NSRect(origin: .zero, size: renderer.displaySize(width: 280, showBezel: true)), styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    let view = ClockView(renderer: renderer, hapticFeedback: { _ in })
    delegate.window = window; delegate.clockView = view; window.contentView = view
    view.onInteraction = { [weak delegate] in delegate?.performInteraction($0) }
    view.onRotation = { [weak delegate] in delegate?.rotateHeritage(by: $0) }
    defer {
        view.onInteraction = nil; view.onRotation = nil; view.cancelMechanicalPresses()
        delegate.timer?.invalidate(); delegate.gshockServiceTimer?.invalidate()
        preferences.removePersistentDomain(forName: suite); window.close()
    }
    let menu = delegate.makeClockMenu(); delegate.menuNeedsUpdate(menu)
    expect(delegate.menuActions["interaction"]?.isHidden == false && delegate.menuActions["stopStep"]?.isHidden == false &&
           delegate.menuActions["chronoToggle"]?.isHidden == true, "Chronostop needs its own one-button interaction")
    var now: TimeInterval = 0
    delegate.chronostop = Chronostop(now: { now })
    func event(_ type: NSEvent.EventType, _ point: NSPoint) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 0)!
    }
    let pusher = view.subviews.compactMap { $0 as? MechanicalButton }.first!
    for width: CGFloat in [180, 280, 466] {
        window.setContentSize(renderer.displaySize(width: width, showBezel: true)); view.layoutSubtreeIfNeeded()
        expect(view.hitTest(NSPoint(x: pusher.frame.midX, y: pusher.frame.midY)) === pusher, "Chronostop pusher must match the case at every size")
    }
    let point = pusher.convert(NSPoint(x: pusher.bounds.midX, y: pusher.bounds.midY), to: nil)
    pusher.mouseDown(with: event(.leftMouseDown, point)); now += 0.2
    pusher.mouseUp(with: event(.leftMouseUp, point))
    expect(delegate.chronostop.isRunning, "First release must keep Chronostop running")
    now += 17
    pusher.mouseDown(with: event(.leftMouseDown, point)); now += 4
    expect(delegate.chronostop.readingHeld && abs(delegate.chronostop.reading.elapsed - 17.2) < 0.001, "Second press holds the reading")
    view.showBezel = false
    expect(!delegate.chronostop.readingHeld && delegate.chronostop.reading.elapsed == 0, "Hiding the pusher must release and reset a held reading")
    delegate.chronostopMenuAction(); now += 3; delegate.chronostopMenuAction()
    expect(delegate.chronostop.readingHeld, "Interaction must support a latched reading without the case")
    delegate.chronostopMenuAction(); expect(delegate.chronostop.reading.elapsed == 0, "The next menu action resets")

    let selection = NSMenuItem(); selection.representedObject = "jlc-memovox-parking"; delegate.selectTheme(selection)
    view.showBezel = true; view.layoutSubtreeIfNeeded()
    let crown = view.subviews.compactMap { $0 as? MechanicalButton }.first!
    let crownPoint = crown.convert(NSPoint(x: crown.bounds.midX, y: crown.bounds.midY), to: nil)
    let angle = delegate.parking.settings.angle
    crown.mouseDown(with: event(.leftMouseDown, crownPoint))
    crown.mouseDragged(with: event(.leftMouseDragged, NSPoint(x: crownPoint.x, y: crownPoint.y - 20)))
    crown.mouseUp(with: event(.leftMouseUp, NSPoint(x: crownPoint.x, y: crownPoint.y - 20)))
    expect(abs(delegate.parking.settings.angle - ParkingAlarm.normalized(angle + 10)) < 0.001 && !delegate.parking.isArmed,
           "Dragging the upper crown rotates the disc without an accidental click")
    crown.performClick(nil); expect(delegate.parking.isArmed, "Crown click arms the disc's selected time")
    let duration = NSMenuItem(); duration.tag = 30; delegate.setParkingDuration(duration)
    expect(delegate.parking.settings.deadline!.timeIntervalSinceNow > 1790, "Parking presets must arm a real deadline")
    delegate.pauseForSleep(); delegate.wakeFromSleep()
    expect(delegate.parking.isArmed, "Sleep must preserve the parking reminder")
    delegate.cancelParking(); expect(!delegate.parking.isArmed, "Cancel must clear the saved reminder")

    selection.representedObject = "breitling-navitimer"; delegate.selectTheme(selection)
    view.layoutSubtreeIfNeeded(); delegate.menuNeedsUpdate(menu)
    expect(delegate.menuActions["slideReset"]?.isHidden == false && delegate.menuActions["chronoToggle"]?.isHidden == false,
           "Navitimer must expose the scale and chronograph together")
    let ring = view.subviews.compactMap { $0 as? RotaryRing }.first!
    expect(ring.hitTest(NSPoint(x: ring.frame.midX, y: ring.frame.midY)) == nil, "The scale must not intercept the center used for moving the watch")
    let top = ring.convert(NSPoint(x: ring.bounds.midX, y: ring.bounds.height * 0.96), to: nil)
    let right = ring.convert(NSPoint(x: ring.bounds.width * 0.96, y: ring.bounds.midY), to: nil)
    ring.mouseDown(with: event(.leftMouseDown, top)); ring.mouseDragged(with: event(.leftMouseDragged, right)); ring.mouseUp(with: event(.leftMouseUp, right))
    expect(abs(delegate.slideRuleAngle - 90) < 0.01 && preferences.double(forKey: "slideRuleAngle") == delegate.slideRuleAngle,
           "A quarter-turn gesture must rotate the scale by 90 degrees and save it")
    delegate.resetSlideRule(); expect(delegate.slideRuleAngle == 0, "Reset returns the two calculation scales to alignment")
    delegate.toggleChronograph(); expect(delegate.chronograph.isRunning, "Navitimer must reuse the working three-counter chronograph")
    delegate.resetChronograph()
    view.showBezel = false; view.layoutSubtreeIfNeeded()
    expect(ring.frame == view.bounds, "The logarithmic ring must also rotate in dial-only mode")
    print("Passed: Chronostop real hold/release/menu, Memovox crown drag/arm/presets/sleep/cancel, Navitimer ring gestures/center hit testing/persistence/chronograph")
}
