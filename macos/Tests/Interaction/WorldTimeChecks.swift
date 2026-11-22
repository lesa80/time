import AppKit

@MainActor
func checkWorldTimeInterface(library: ThemeLibrary) throws {
    let suite = "local.vremya.world-time-tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.set(280, forKey: "diameter")
    defaults.set(true, forKey: "showBezel")
    defaults.set(353.0, forKey: "cityRingAngle")
    defaults.set(97, forKey: "worldTimeOffsetMinutes")
    let renderer = try library.renderer(for: "goroda")
    let delegate = AppDelegate(library: library, renderer: renderer, defaults: defaults, signalSound: {}, buttonSound: { _ in })
    let window = ClockWindow(contentRect: NSRect(origin: .zero, size: renderer.displaySize(width: 280, showBezel: true)),
                             styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    let view = ClockView(renderer: renderer, hapticFeedback: { _ in })
    window.contentView = view
    delegate.window = window
    delegate.clockView = view
    view.onRotation = { [weak delegate] in delegate?.rotateHeritage(by: $0) }
    defer {
        delegate.timer?.invalidate()
        delegate.gshockServiceTimer?.invalidate()
        defaults.removePersistentDomain(forName: suite)
        window.close()
    }
    view.layoutSubtreeIfNeeded()
    let menu = delegate.makeClockMenu()
    delegate.menuNeedsUpdate(menu)
    expect(delegate.cityRingAngle == 0, "A saved 353° alignment must snap forward across midnight")
    let interaction = delegate.menuActions["interaction"]!
    let actions = interaction.submenu!
    let diskItems = ["cityLeft", "cityRight", "cityReset"].map { delegate.menuActions[$0]! }
    expect(!interaction.isHidden && Set(actions.items.filter { !$0.isHidden && !$0.isSeparatorItem }) == Set(diskItems),
           "World Time must expose only the backward, forward and reset disk actions")

    let crowns = view.subviews.compactMap { $0 as? MechanicalButton }
    expect(crowns.count == 1 && crowns[0].control.action == .cityCrown, "Only the upper crown should be interactive")
    let crown = crowns[0]
    let accessibleTurns = crown.accessibilityCustomActions() ?? []
    expect(accessibleTurns.count == 2, "The upper crown must expose both directions to VoiceOver")
    expect(accessibleTurns[0].handler?() == true && delegate.cityRingAngle == 345, "One accessible backward turn moves one time zone")
    expect(accessibleTurns[1].handler?() == true && delegate.cityRingAngle == 0, "One accessible forward turn moves one time zone")
    let start = crown.convert(NSPoint(x: crown.bounds.midX, y: crown.bounds.midY), to: nil)
    func mouse(_ type: NSEvent.EventType, _ point: NSPoint) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                           context: nil, eventNumber: 0, clickCount: 1, pressure: 0)!
    }
    func crownPoint(_ dy: CGFloat) -> NSPoint { NSPoint(x: start.x, y: start.y - dy) }
    crown.mouseDown(with: mouse(.leftMouseDown, start))
    for dy in [8, 14, 22] { crown.mouseDragged(with: mouse(.leftMouseDragged, crownPoint(CGFloat(dy)))) }
    expect(delegate.cityRingAngle == 0, "Sub-hour movements must accumulate without shifting the visible disk")
    crown.mouseDragged(with: mouse(.leftMouseDragged, crownPoint(30)))
    expect(delegate.cityRingAngle == 15 && view.heritage.cityRingAngle == 15, "One hour turns the visible disk exactly 15°")
    crown.mouseDragged(with: mouse(.leftMouseDragged, crownPoint(90)))
    expect(delegate.cityRingAngle == 45, "A large drag may advance several complete time zones")
    crown.mouseDragged(with: mouse(.leftMouseDragged, crownPoint(48)))
    expect(delegate.cityRingAngle == 30, "Reversing a drag must step the disk backward")
    crown.mouseUp(with: mouse(.leftMouseUp, crownPoint(48)))
    crown.mouseDown(with: mouse(.leftMouseDown, start))
    crown.mouseDragged(with: mouse(.leftMouseDragged, crownPoint(-20)))
    crown.mouseUp(with: mouse(.leftMouseUp, crownPoint(-20)))
    expect(delegate.cityRingAngle == 30, "A new drag must not inherit the previous drag's fractional distance")

    delegate.updateClock()
    view.date = Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 23, minute: 59, second: 41))!
    expect(view.handAngles.hours == 23 && view.handAngles.minutes == 59 && view.handAngles.seconds == 41,
           "Legacy manual time adjustment must never shift the hands away from system time")
    for _ in 0..<3 { actions.performActionForItem(at: actions.index(of: diskItems[0])) }
    expect(delegate.cityRingAngle == 345, "One-hour menu steps must wrap below zero")
    actions.performActionForItem(at: actions.index(of: diskItems[1]))
    expect(delegate.cityRingAngle == 0, "One-hour menu steps must wrap above 345°")

    view.showBezel = false
    window.setContentSize(renderer.displaySize(width: 280, showBezel: false))
    view.layoutSubtreeIfNeeded()
    expect(crown.isHidden, "The upper crown hit area must disappear with the case")
    let ring = view.subviews.compactMap { $0 as? RotaryRing }.first!
    func rimPoint(_ degrees: Double) -> NSPoint {
        let angle = degrees * .pi / 180, r = ring.bounds.width * 0.46
        return ring.convert(NSPoint(x: ring.bounds.midX + r * sin(angle), y: ring.bounds.midY + r * cos(angle)), to: nil)
    }
    ring.mouseDown(with: mouse(.leftMouseDown, rimPoint(-5)))
    ring.mouseDragged(with: mouse(.leftMouseDragged, rimPoint(3)))
    expect(delegate.cityRingAngle == 0, "A short drag across the top of the dial must stay in its detent")
    ring.mouseDragged(with: mouse(.leftMouseDragged, rimPoint(12)))
    ring.mouseUp(with: mouse(.leftMouseUp, rimPoint(12)))
    expect(delegate.cityRingAngle == 15, "The dial-only ring must step once after crossing twelve o'clock")
    let reopened = AppDelegate(library: library, renderer: renderer, defaults: defaults, signalSound: {}, buttonSound: { _ in })
    expect(reopened.cityRingAngle == 15, "Restart must restore the selected whole-hour position")
    defaults.set(38.0, forKey: "cityRingAngle")
    let migrated = AppDelegate(library: library, renderer: renderer, defaults: defaults, signalSound: {}, buttonSound: { _ in })
    expect(migrated.cityRingAngle == 45, "Legacy free rotations must migrate to the nearest hour")
    actions.performActionForItem(at: actions.index(of: diskItems[2]))
    expect(delegate.cityRingAngle == 0, "Reset must restore the original disk alignment")
    let selection = NSMenuItem()
    selection.representedObject = "breitling-navitimer"
    delegate.selectTheme(selection)
    delegate.menuNeedsUpdate(menu)
    expect(diskItems.allSatisfy(\.isHidden), "City disk actions must stay private to World Time")
    print("Passed: World Time disk-only controls, hourly crown and dial steps, independent gestures, migration and persistence")
}
