import AppKit

@MainActor
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        FileHandle.standardError.write(Data(("Interaction test failed: " + message + "\n").utf8))
        exit(1)
    }
}

// Exercise actual view handlers with local events in an unshown window.
// No system events are posted and no user preferences are changed.
let application = NSApplication.shared
application.setActivationPolicy(.prohibited)
let library = try ThemeLibrary(resources: URL(fileURLWithPath: CommandLine.arguments[1]))
if let index = CommandLine.arguments.firstIndex(of: "--localization-only") {
    try checkLocalizedInterface(library: library, expectedLanguage: CommandLine.arguments[index + 1])
    exit(0)
}
let renderer = try library.renderer(for: "avangard")
let window = ClockWindow(contentRect: NSRect(x: 200, y: 200, width: 280, height: 280),
                         styleMask: [.borderless], backing: .buffered, defer: false)
window.isReleasedWhenClosed = false
let view = ClockView(renderer: renderer)
view.showBezel = false
window.contentView = view
var interactions = 0
view.onInteraction = { _ in interactions += 1 }
@MainActor
func send(_ type: NSEvent.EventType, at point: NSPoint, flags: NSEvent.ModifierFlags = []) {
    let event = NSEvent.mouseEvent(with: type, location: window.convertPoint(fromScreen: point),
        modifierFlags: flags, timestamp: 0, windowNumber: window.windowNumber, context: nil,
        eventNumber: 0, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1)!
    switch type {
    case .leftMouseDown: view.mouseDown(with: event)
    case .leftMouseDragged: view.mouseDragged(with: event)
    case .leftMouseUp: view.mouseUp(with: event)
    case .rightMouseDown: view.rightMouseDown(with: event)
    default: fatalError("Unexpected test event")
    }
}
@MainActor
func center() -> NSPoint { window.convertPoint(toScreen: NSPoint(x: 140, y: 140)) }
let start = center()
send(.leftMouseDown, at: start)
send(.leftMouseUp, at: start)
expect(interactions == 0, "A dial click must not toggle the bezel or trigger an interaction")
send(.leftMouseUp, at: start)
expect(interactions == 0, "A release without a press must not toggle")

let originalFrame = window.frame
let slightMovement = NSPoint(x: start.x + 2, y: start.y + 1)
send(.leftMouseDown, at: start)
send(.leftMouseDragged, at: slightMovement)
send(.leftMouseUp, at: slightMovement)
expect(interactions == 0 && window.frame == originalFrame, "Pointer jitter must not move the window or trigger an interaction")

let moved = NSPoint(x: start.x + 36, y: start.y + 18)
send(.leftMouseDown, at: start)
send(.leftMouseDragged, at: moved)
expect(window.frame.origin == NSPoint(x: originalFrame.minX + 36, y: originalFrame.minY + 18),
             "Dragging must move the clock by the screen-space pointer displacement")
send(.leftMouseUp, at: moved)
expect(interactions == 0, "Dragging must not toggle the bezel")

let nextStart = center()
send(.leftMouseDown, at: nextStart)
send(.leftMouseDragged, at: NSPoint(x: nextStart.x + 20, y: nextStart.y))
send(.leftMouseDragged, at: nextStart)
send(.leftMouseUp, at: nextStart)
expect(interactions == 0, "Returning a drag to its starting point must not become a click")

send(.leftMouseDown, at: center(), flags: .control)
send(.leftMouseUp, at: center(), flags: .control)
send(.rightMouseDown, at: center())
expect(interactions == 0, "Context-menu clicks must not toggle the bezel")
send(.leftMouseDown, at: center())
send(.leftMouseUp, at: NSPoint(x: window.frame.maxX + 10, y: window.frame.maxY + 10))
expect(interactions == 0, "Releasing outside the clock must not toggle")
expect(!view.accessibilityPerformPress() && !view.showBezel, "The clock image must not expose a bezel press action")
expect(view.acceptsFirstMouse(for: nil), "A click must work when the app is inactive")

// Compare the live view's static-layer cache against the uncached renderer.
// Render locally into bitmaps; no screen capture permission is involved.
@MainActor
func pixels(cached: Bool, renderer: DialRenderer, showBezel: Bool, width: CGFloat = 280, seconds: Bool = false, advance: TimeInterval = 61, elapsed: TimeInterval = 0) -> [UInt8] {
    let size = renderer.displaySize(width: width, showBezel: showBezel)
    window.setContentSize(size)
    // AppKit rounds window frames to pixels; explicitly exercise fractional view bounds too.
    view.setBoundsSize(size)
    view.renderer = renderer
    view.showBezel = showBezel
    view.showSeconds = seconds
    view.chronograph = ChronographReading()
    view.date = Date(timeIntervalSince1970: 1_700_000_000)
    let scale = window.backingScaleFactor
    let pixelWidth = Int(ceil(size.width * scale)), height = Int(ceil(size.height * scale))
    let bitmap = CGContext(data: nil, width: pixelWidth, height: height, bitsPerComponent: 8, bytesPerRow: pixelWidth * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    bitmap.scaleBy(x: CGFloat(pixelWidth) / size.width, y: CGFloat(height) / size.height)
    if cached {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: bitmap, flipped: false)
        view.draw(view.bounds)
        // A second frame exercises reuse rather than only cache initialization.
        bitmap.clear(CGRect(origin: .zero, size: size))
        view.date = view.date.addingTimeInterval(advance)
        view.chronograph = ChronographReading(elapsed: elapsed)
        view.draw(view.bounds)
        NSGraphicsContext.restoreGraphicsState()
    } else {
        renderer.draw(in: bitmap, size: size, angles: HandAngles(date: view.date.addingTimeInterval(advance),
            hourCycle: renderer.theme.hourCycle, direction: renderer.theme.rotationDirection), showSeconds: seconds, showBezel: showBezel,
            chronograph: ChronographReading(elapsed: elapsed))
    }
    return Array(UnsafeBufferPointer(start: bitmap.data!.assumingMemoryBound(to: UInt8.self), count: pixelWidth * height * 4))
}
let fractionalCached = pixels(cached: true, renderer: renderer, showBezel: true, width: 280.3)
let fractionalDirect = pixels(cached: false, renderer: renderer, showBezel: true, width: 280.3)
let fractionalError = zip(fractionalCached, fractionalDirect).reduce(0.0) { $0 + abs(Double($1.0) - Double($1.1)) } / Double(fractionalCached.count)
expect(fractionalError < 0.6, "Fractional-size cache alignment: \(fractionalError)")
for theme in library.catalog.themes {
    let renderer = try library.renderer(for: theme.id)
    for bezel in [true, false] {
        let cached = pixels(cached: true, renderer: renderer, showBezel: bezel)
        let direct = pixels(cached: false, renderer: renderer, showBezel: bezel)
        let difference = zip(cached, direct).reduce(0.0) { $0 + abs(Double($1.0) - Double($1.1)) } / Double(cached.count)
        expect(difference < 0.6, "Cached artwork differs from direct rendering: \(theme.id), bezel=\(bezel), error=\(difference)")
    }
}

// Running seconds must animate inside the left subdial, including with the static cache reused.
let moonwatch = try library.renderer(for: "omega-speedmaster")
let moonStart = pixels(cached: true, renderer: moonwatch, showBezel: true, width: 500, seconds: true, advance: 0)
let moonLater = pixels(cached: true, renderer: moonwatch, showBezel: true, width: 500, seconds: true, advance: 15)
let moonWidth = Int(ceil(500 * window.backingScaleFactor))
let moonScale = Double(moonWidth) / moonwatch.specification.resolution[0]
let secondLayer = moonwatch.layers.first { $0.spec.image.hasSuffix("/second.png") }!
let axis = secondLayer.spec.handResPosition!
var movedSecondPixels = 0
for y in Int((axis[1] - 75) * moonScale)..<Int((axis[1] + 75) * moonScale) {
    for x in Int((axis[0] - 75) * moonScale)..<Int((axis[0] + 75) * moonScale) {
        let index = (y * moonWidth + x) * 4
        if moonStart[index..<(index + 4)] != moonLater[index..<(index + 4)] { movedSecondPixels += 1 }
    }
}
expect(movedSecondPixels > 30, "Moonwatch running seconds must move inside the left subdial")
print("Passed: Moonwatch left running seconds animates with cached static artwork")

expect(moonwatch.hasChronograph && !renderer.hasChronograph, "Only the Moonwatch must expose chronograph controls")
for bezel in [true, false] {
    for seconds in [true, false] {
        let cached = pixels(cached: true, renderer: moonwatch, showBezel: bezel, seconds: seconds, advance: 0, elapsed: 7635)
        let direct = pixels(cached: false, renderer: moonwatch, showBezel: bezel, seconds: seconds, advance: 0, elapsed: 7635)
        let difference = zip(cached, direct).reduce(0.0) { $0 + abs(Double($1.0) - Double($1.1)) } / Double(cached.count)
        expect(difference < 0.6, "Live chronograph must match direct drawing, including after caching and when seconds are hidden")
    }
}
let chronoZero = pixels(cached: true, renderer: moonwatch, showBezel: true, width: 500, seconds: false, advance: 0)
let chronoRunning = pixels(cached: true, renderer: moonwatch, showBezel: true, width: 500, seconds: false, advance: 0, elapsed: 7635)
for name in ["chrono-second", "chrono-minute", "chrono-hour"] {
    let layer = moonwatch.layers.first { $0.spec.image.hasSuffix("/\(name).png") }!.spec
    let axis = layer.handResPosition!
    var changed = 0
    for y in Int((axis[1] - 72) * moonScale)..<Int((axis[1] + 72) * moonScale) {
        for x in Int((axis[0] - 72) * moonScale)..<Int((axis[0] + 72) * moonScale) {
            let i = (y * moonWidth + x) * 4
            if chronoZero[i..<(i + 4)] != chronoRunning[i..<(i + 4)] { changed += 1 }
        }
    }
    expect(changed > 30, "\(name) must visibly move while the current seconds hand is hidden")
}
print("Passed: all three chronograph hands move independently with cached artwork, with/without bezel and running seconds")

let suite = "local.raketa.tests.\(UUID().uuidString)"
let preferences = UserDefaults(suiteName: suite)!
preferences.set(280, forKey: "diameter")
preferences.set(false, forKey: "showBezel")
let delegate = AppDelegate(library: library, renderer: renderer, defaults: preferences)
delegate.window = window
delegate.clockView = view
view.renderer = renderer
view.showBezel = false
delegate.toggleBezel()
expect(preferences.bool(forKey: "showBezel") && view.showBezel, "Toggle must save full-watch mode")
delegate.toggleBezel()
expect(!preferences.bool(forKey: "showBezel") && !view.showBezel, "Toggle must restore dial-only mode")
expect(abs(window.frame.width - 280) < 0.1, "Mode changes must retain the preferred width")
delegate.pauseForSleep()
expect(delegate.timer == nil, "System sleep must stop redraws")
// Exercise the actual menu builder without registering a system status item.
let menu = delegate.makeThemeMenu()
expect(menu.items.first?.representedObject as? String == "minimalism", "Own theme must be outside the Raketa section")
let brand = menu.items.first { $0.title == L("Raketa") }!
expect(brand.image != nil && brand.image?.isTemplate == false, "Brand section must keep the red logo")
expect(brand.submenu?.items.count == 21, "All manufacturer themes must be grouped")
let icons = menu.items.first { $0.title == L("Legendary models") }!
expect(icons.submenu?.items.count == 11, "All legendary models and color variants must be grouped")

// Exercise the actual NSMenu targets with a deterministic monotonic clock.
var chronographNow: TimeInterval = 100
let chronoDelegate = AppDelegate(library: library, renderer: moonwatch, defaults: preferences)
chronoDelegate.chronograph = Chronograph(now: { chronographNow })
chronoDelegate.window = window
chronoDelegate.clockView = view
view.renderer = moonwatch
let chronoMenu = chronoDelegate.makeClockMenu()
chronoDelegate.menuNeedsUpdate(chronoMenu)
let controls = chronoDelegate.menuActions["interaction"]!.submenu!
expect(chronoDelegate.menuActions["interaction"]?.isHidden == false, "Speedmaster controls must be discoverable in the settings menu")
expect(chronoDelegate.menuActions["chronoReset"]?.isEnabled == false, "Reset must be disabled at zero")
controls.performActionForItem(at: 0)
expect(chronoDelegate.chronograph.isRunning && chronoDelegate.menuActions["chronoToggle"]?.title == L("Pause chronograph"), "Menu Start must start the chronograph")
chronographNow += 7635
chronoDelegate.updateClock()
expect(view.chronograph.elapsed == 7635 && chronoDelegate.menuActions["chronoElapsed"]?.title.contains("02:07:15") == true,
       "View, menu and elapsed time must use the same chronograph")
controls.performActionForItem(at: 0)
chronographNow += 90
chronoDelegate.updateClock()
expect(!chronoDelegate.chronograph.isRunning && view.chronograph.elapsed == 7635 &&
       chronoDelegate.menuActions["chronoToggle"]?.title == L("Resume chronograph"), "Menu Pause must freeze the elapsed time")
controls.performActionForItem(at: 0)
chronoDelegate.renderer = renderer
chronoDelegate.menuNeedsUpdate(chronoMenu)
expect(chronoDelegate.menuActions["interaction"]?.isHidden == true, "Other themes must hide chronograph controls")
chronoDelegate.pauseForSleep()
chronographNow += 3600
expect(chronoDelegate.timer == nil && chronoDelegate.chronograph.reading.elapsed == 11235,
       "Theme switches and system sleep must preserve running elapsed time without redraws")
chronoDelegate.renderer = moonwatch
chronoDelegate.menuNeedsUpdate(chronoMenu)
controls.performActionForItem(at: 1)
expect(!chronoDelegate.chronograph.isRunning && view.chronograph.elapsed == 0 &&
       chronoDelegate.menuActions["chronoToggle"]?.title == L("Start chronograph"), "Menu Reset must stop and zero all counters")
// The mechanical controls are real buttons aligned with the raster case at every size.
view.renderer = moonwatch
view.showBezel = true
view.onInteraction = { chronoDelegate.performInteraction($0) }
for width: CGFloat in [180, 280, 466] {
    let size = moonwatch.displaySize(width: width, showBezel: true)
    window.setContentSize(size)
    view.setBoundsSize(size)
    view.layoutSubtreeIfNeeded()
    let buttons = view.subviews.compactMap { $0 as? MechanicalButton }
    expect(buttons.count == 2, "Speedmaster must have two mechanical controls")
    let upper = buttons.first { $0.control.action == .chronographToggle }!
    let lower = buttons.first { $0.control.action == .chronographReset }!
    expect(upper.frame.midY > lower.frame.midY, "Start/pause must be above reset")
    for button in buttons {
        expect(!button.isHidden && view.hitTest(NSPoint(x: button.frame.midX, y: button.frame.midY)) === button,
               "Visible mechanical buttons must receive clicks at width \(width)")
    }
    upper.performClick(nil)
    expect(chronoDelegate.chronograph.isRunning, "Upper pusher must start")
    chronographNow += 2
    chronoDelegate.updateClock()
    upper.performClick(nil)
    expect(!chronoDelegate.chronograph.isRunning && view.chronograph.elapsed == 2, "Upper pusher must pause")
    upper.performClick(nil)
    expect(chronoDelegate.chronograph.isRunning, "Upper pusher must resume")
    lower.performClick(nil)
    expect(!chronoDelegate.chronograph.isRunning && view.chronograph.elapsed == 0, "Lower pusher must reset")
}

// Hover feedback is requested once per entry; tests never vibrate the user's trackpad.
var hapticRequests = 0, probePresses = 0
let pusherControl = moonwatch.specification.mechanicalControls!.first!
let probe = MechanicalButton(control: pusherControl, hapticFeedback: { _ in hapticRequests += 1 }) { probePresses += 1 }
probe.frame = NSRect(x: 0, y: 0, width: 32, height: 40)
view.addSubview(probe)
probe.updateTrackingAreas()
let trackingCount = probe.trackingAreas.count
probe.updateTrackingAreas()
expect(probe.trackingAreas.count == trackingCount && probe.trackingAreas.contains { $0.options.contains(.activeAlways) },
       "Hover tracking must work in the non-key clock window without accumulating tracking areas")
@MainActor
func hover(_ type: NSEvent.EventType) -> NSEvent {
    NSEvent.enterExitEvent(with: type, location: .zero, modifierFlags: [], timestamp: 0,
        windowNumber: window.windowNumber, context: nil, eventNumber: 0, trackingNumber: 0, userData: nil)!
}
probe.mouseEntered(with: hover(.mouseEntered))
probe.mouseEntered(with: hover(.mouseEntered))
expect(hapticRequests == 1 && probePresses == 0, "Hover must provide one pulse without activating the watch")
probe.mouseExited(with: hover(.mouseExited))
probe.mouseEntered(with: hover(.mouseEntered))
expect(hapticRequests == 2, "Leaving and reentering an active pusher must provide a new pulse")
probe.isEnabled = false
probe.mouseExited(with: hover(.mouseExited))
probe.mouseEntered(with: hover(.mouseEntered))
expect(hapticRequests == 2, "Disabled pushers must not request haptics")
probe.isEnabled = true
probe.isHidden = true
probe.mouseEntered(with: hover(.mouseEntered))
expect(hapticRequests == 2, "Hidden pushers must not request haptics")
probe.isHidden = false
view.isHidden = true
probe.mouseEntered(with: hover(.mouseEntered))
expect(hapticRequests == 2, "A hidden parent must suppress haptics")
view.isHidden = false
window.ignoresMouseEvents = true
probe.mouseEntered(with: hover(.mouseEntered))
expect(hapticRequests == 2, "Locked clocks must not request hover feedback")
window.ignoresMouseEvents = false
probe.performClick(nil)
expect(probePresses == 1 && hapticRequests == 2, "Removing visual feedback must preserve the button action")

let pusherBitmap = CGContext(data: nil, width: 32, height: 40, bitsPerComponent: 8, bytesPerRow: 32 * 4,
    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: pusherBitmap, flipped: false)
for pressed in [false, true] {
    pusherBitmap.clear(probe.bounds)
    probe.highlight(pressed)
    probe.draw(probe.bounds)
    let bytes = UnsafeBufferPointer(start: pusherBitmap.data!.assumingMemoryBound(to: UInt8.self), count: 32 * 40 * 4)
    expect(stride(from: 3, to: bytes.count, by: 4).allSatisfy { bytes[$0] == 0 },
           "Resting and pressed pushers must leave the case artwork untouched")
}
probe.highlight(false)
NSGraphicsContext.restoreGraphicsState()
probe.removeFromSuperview()
probe.mouseEntered(with: hover(.mouseEntered))
expect(hapticRequests == 2, "Detached controls must not provide haptics")
print("Passed: invisible pressed buttons, one hover pulse per entry and haptic suppression for disabled/hidden/locked controls")

// Route motion through the actual non-key NSWindow, without manually calling mouseEntered.
let originalContentSize = window.contentView!.frame.size
let originalBounds = view.bounds
var routedHaptics = 0
let routedView = ClockView(renderer: moonwatch, hapticFeedback: { _ in routedHaptics += 1 })
window.contentView = routedView
window.setContentSize(moonwatch.displaySize(width: 280, showBezel: true))
routedView.chronographIsRunning = true
routedView.layoutSubtreeIfNeeded()
expect(window.acceptsMouseMovedEvents && !window.canBecomeKey && !window.isKeyWindow,
       "Desktop clock must accept motion without becoming the key window")
let routedButtons = routedView.subviews.compactMap { $0 as? MechanicalButton }
let routedUpper = routedButtons.first { $0.control.action == .chronographToggle }!
let routedLower = routedButtons.first { $0.control.action == .chronographReset }!
@MainActor
func routeMotion(to button: MechanicalButton?) {
    let point = button.map { $0.convert(NSPoint(x: $0.bounds.midX, y: $0.bounds.midY), to: nil) } ??
        routedView.convert(NSPoint(x: routedView.bounds.midX, y: routedView.bounds.midY), to: nil)
    let event = NSEvent.mouseEvent(with: .mouseMoved, location: point, modifierFlags: [], timestamp: 0,
        windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 0, pressure: 0)!
    window.sendEvent(event)
}
routeMotion(to: routedUpper)
expect(routedHaptics == 1 && NSCursor.current == .pointingHand,
       "Window motion must establish hover and cursor even if no entered event arrived")
routeMotion(to: routedUpper)
expect(routedHaptics == 1, "Movement within the same pusher must not repeat the pulse")
routeMotion(to: routedLower)
expect(routedHaptics == 2 && NSCursor.current == .pointingHand, "Switching to the lower pusher must preserve the hand cursor")
routeMotion(to: routedUpper)
expect(routedHaptics == 3 && NSCursor.current == .pointingHand, "Switching back must clear old hover before setting the new cursor")
routeMotion(to: nil)
expect(routedHaptics == 3 && NSCursor.current == .arrow, "Leaving pushers must restore the cursor")
routeMotion(to: routedUpper)
window.ignoresMouseEvents = true
expect(NSCursor.current == .arrow, "Locking the window must immediately clear hover")
routeMotion(to: routedUpper)
expect(routedHaptics == 4, "Window-level dispatch must honor click-through mode")
window.ignoresMouseEvents = false
routeMotion(to: routedUpper)
expect(routedHaptics == 5, "Unlocking must allow a new hover without an entered event")
routedView.showBezel = false
routeMotion(to: routedUpper)
expect(routedHaptics == 5 && NSCursor.current == .arrow, "Hidden case controls must not receive routed hover")
window.contentView = view
window.setContentSize(originalContentSize)
view.bounds = originalBounds
print("Passed: real non-key window motion dispatch, visible hand cursor, deduplicated hover and lock/hide cleanup")


// Real settings actions select the requested native pattern and persist without affecting watch controls.
do {
    let hapticSuite = suite + ".haptics"
    let hapticDefaults = UserDefaults(suiteName: hapticSuite)!
    defer { hapticDefaults.removePersistentDomain(forName: hapticSuite); window.contentView = view }
    var patterns: [NSHapticFeedbackManager.FeedbackPattern] = []
    var presses = 0
    let feedbackView = ClockView(renderer: moonwatch, hapticFeedback: { patterns.append($0) })
    feedbackView.onInteraction = { _ in presses += 1 }
    window.contentView = feedbackView
    let feedbackDelegate = AppDelegate(library: library, renderer: moonwatch, defaults: hapticDefaults)
    feedbackDelegate.clockView = feedbackView
    expect(feedbackDelegate.hapticMode == .generic, "Fresh installs must retain generic feedback")
    hapticDefaults.set("unknown", forKey: "hapticFeedback")
    expect(feedbackDelegate.hapticMode == .generic, "Unknown saved patterns must fall back to generic feedback")
    _ = feedbackDelegate.makeClockMenu()
    let expectedPatterns: [NSHapticFeedbackManager.FeedbackPattern?] = [nil, .generic, .alignment, .levelChange]
    expect(feedbackDelegate.hapticMenu.items.count == 4, "Settings must offer off and all three native patterns")
    for (index, mode) in HapticMode.allCases.enumerated() {
        feedbackDelegate.hapticMenu.performActionForItem(at: index)
        expect(feedbackDelegate.hapticMode == mode && feedbackView.hapticMode == mode,
               "Selecting a mode must immediately apply and save it")
        expect(feedbackDelegate.hapticMenu.items.filter { $0.state == .on }.count == 1 &&
               feedbackDelegate.hapticMenu.items[index].state == .on, "Exactly the selected feedback option must be checked")
        let reloaded = AppDelegate(library: library, renderer: moonwatch, defaults: UserDefaults(suiteName: hapticSuite)!)
        expect(reloaded.hapticMode == mode, "Selected feedback must survive reloading preferences")
        feedbackView.renderer = moonwatch
        let button = feedbackView.subviews.compactMap { $0 as? MechanicalButton }.first { $0.control.action == .chronographToggle }!
        let previousCount = patterns.count
        button.mouseEntered(with: hover(.mouseEntered))
        button.mouseEntered(with: hover(.mouseEntered))
        if let expected = expectedPatterns[index] {
            expect(patterns.count == previousCount + 1 && patterns.last == expected,
                   "The selected native pattern must be requested once after a theme rebuild")
        } else {
            expect(patterns.count == previousCount && NSCursor.current == .pointingHand,
                   "Disabled feedback must suppress vibration while preserving the hover cursor")
        }
        button.performClick(nil)
        button.mouseExited(with: hover(.mouseExited))
    }
    expect(presses == 4, "All feedback modes must preserve mechanical button actions")
    let invalid = NSMenuItem()
    invalid.representedObject = "unknown"
    feedbackDelegate.selectHapticMode(invalid)
    expect(feedbackDelegate.hapticMode == .levelChange, "Invalid settings actions must not overwrite the saved choice")
}
print("Passed: all haptic settings actions, exact native patterns, disabled feedback, saved preference and theme rebuilds")

view.showBezel = false
expect(view.subviews.compactMap { $0 as? MechanicalButton }.allSatisfy(\.isHidden), "Dial-only mode must hide pusher hit areas")
expect(view.accessibilityRole() == .image, "Hidden case controls must not make the dial a button")
view.showBezel = true
expect(view.accessibilityRole() == .group, "Visible case controls must be exposed as accessible buttons")
expect(chronoMenu.items[1] === chronoDelegate.menuActions["interaction"], "Interaction must immediately follow the current model title")
expect(chronoDelegate.menuActions["showBezel"]?.menu?.title == L("Appearance") &&
       chronoDelegate.menuActions["aboveWindows"]?.menu?.title == L("Window"), "Settings must be grouped by purpose")
expect(chronoMenu.items.filter { !$0.isSeparatorItem && !$0.isHidden }.count == 9 &&
       chronoMenu.items.contains { $0.submenu === chronoDelegate.hapticMenu },
       "Feedback choices must occupy one submenu and keep the root menu compact")
let appearance = chronoDelegate.menuActions["showBezel"]!.menu!
appearance.performActionForItem(at: appearance.index(of: chronoDelegate.menuActions["showBezel"]!))
expect(view.showBezel == preferences.bool(forKey: "showBezel"), "The menu must remain the bezel toggle")
preferences.set(false, forKey: "showBezel")
view.showBezel = false
view.onInteraction = nil
view.renderer = renderer
print("Passed: mechanical pushers at three sizes, hidden hit areas, VoiceOver buttons and compact menu grouping")
print("Passed: real chronograph menu actions, labels, pause/resume, reset, theme switches and sleep")
for theme in library.catalog.themes.filter(\.isIcon) {
    delegate.renderer = try library.renderer(for: theme.id)
    delegate.updateThemeMenuSelection(menu)
    expect(icons.state == .on && brand.state == .off, "Icon selection must select only its own submenu")
}
delegate.renderer = renderer
delegate.updateThemeMenuSelection(menu)
expect(brand.state == .on && brand.submenu?.items.first { $0.representedObject as? String == "avangard" }?.state == .on,
       "Selection must be visible in the nested menu")
expect(menu.items.filter { $0.representedObject != nil }.map { $0.representedObject as! String } == ["minimalism", "minimalism-24", "minimalism-dark", "minimalism-24-dark"],
       "All own themes must be selectable outside the manufacturer section")
for id in ["minimalism", "minimalism-24", "minimalism-dark", "minimalism-24-dark"] {
    let minimalism = try library.renderer(for: id)
    delegate.renderer = minimalism
    view.renderer = minimalism
    view.showBezel = false
    expect(minimalism.hasBezel && minimalism.hasSeconds, "All Minimalism themes must have a case and seconds")
    delegate.toggleBezel()
    expect(preferences.bool(forKey: "showBezel") && view.showBezel, "Minimalism must save full-watch mode")
    delegate.toggleBezel()
    expect(!preferences.bool(forKey: "showBezel") && !view.showBezel, "Minimalism must restore dial-only mode")
    expect(view.hitTest(NSPoint(x: 0, y: 0)) == nil, "Dial-only corners must pass mouse input through")
    expect(!view.accessibilityPerformPress(), "Minimalism must not expose a bezel press action")
    expect(abs(minimalism.displaySize(width: 280, showBezel: false).height - 280) < 1,
           "All separate dials must remain circular")
    expect(minimalism.displaySize(width: 280, showBezel: true).height > 280,
           "All full watches must retain the strap proportions")
    delegate.updateThemeMenuSelection(menu)
    expect(menu.items.first { $0.representedObject as? String == id }?.state == .on && brand.state == .off,
           "Own-theme selection must clear branded selection")
}
for active in [false, true] {
    let icon = delegate.makeMenuBarLogo(active: active)
    expect(icon.isTemplate && icon.size == NSSize(width: 24, height: 18) && icon.representations.count == 3,
           "Neutral tray icon must use template rendering and three Retina representations")
}
let about = AboutWindowController(resources: library.resources, themeCount: library.catalog.themes.count, raketaCount: 21)
@MainActor
func descendants(_ root: NSView) -> [NSView] { [root] + root.subviews.flatMap { descendants($0) } }
let aboutViews = descendants(about.window!.contentView!)
expect(!aboutViews.contains { $0 is NSTabView }, "About must not contain tabs")
expect(aboutViews.filter { $0 is NSScrollView }.count == 1, "About must use a single scrollable page")
let headings = about.contentStack.arrangedSubviews.compactMap { $0.identifier?.rawValue }.filter { $0.hasPrefix("section-") }
expect(headings == ["section-help", "section-icons", "section-raketa", "section-licenses", "section-developer"], "About sections must follow reading order")
expect(aboutViews.contains { $0.identifier?.rawValue == "app-icon" && ($0 as? NSImageView)?.image != nil }, "About must show the supplied app icon")
let developerLogo = aboutViews.first { $0.identifier?.rawValue == "developer-logo" }!
expect(descendants(developerLogo).contains { ($0 as? NSImageView)?.image != nil }, "About must show the supplied developer logo")
for width in [960, 640] {
    for (mode, appearance) in [("light", NSAppearance.Name.aqua), ("dark", NSAppearance.Name.darkAqua)] {
        about.window!.appearance = NSAppearance(named: appearance)
        about.window!.setContentSize(NSSize(width: width, height: 760))
        about.window!.contentView!.layoutSubtreeIfNeeded()
        expect(abs(about.window!.contentView!.bounds.width - CGFloat(width)) < 1,
               "About window must retain requested width: \(width), actual \(about.window!.contentView!.bounds.width)")
        let scroll = about.scrollView
        let document = scroll.documentView!
        document.layoutSubtreeIfNeeded()
        expect(abs(document.bounds.width - scroll.contentView.bounds.width) < 1, "About content must fit each window width")
        expect(document.bounds.height > scroll.contentView.bounds.height, "All sections must remain in one vertically scrolling document")
        for child in about.contentStack.arrangedSubviews {
            let frame = child.convert(child.bounds, to: document)
            expect(frame.minX >= 0 && frame.maxX <= document.bounds.width + 1 && frame.height > 0 && frame.minY >= 0 && frame.maxY <= document.bounds.height + 1,
                   "About controls must fit scrollable content: width=\(width), mode=\(mode), document=\(document.frame), child=\(type(of: child)) \(frame)")
        }
        for bottom in [false, true] {
            scroll.contentView.scroll(to: NSPoint(x: 0, y: bottom ? document.bounds.maxY - scroll.contentView.bounds.height : 0))
            scroll.reflectScrolledClipView(scroll.contentView)
            about.window!.contentView!.layoutSubtreeIfNeeded()
            if bottom {
                let frame = developerLogo.convert(developerLogo.bounds, to: document)
                expect(scroll.contentView.bounds.minY > 0 && scroll.documentVisibleRect.intersects(frame), "Developer section must be reachable by scrolling")
            } else {
                expect(abs(scroll.contentView.bounds.minY) < 1, "About must scroll back to the app header")
            }
            // Render this app's own unshown view only, without screen capture.
            let position = bottom ? "bottom" : "top"
            let url = URL(fileURLWithPath: "macos/.build/previews/about-\(mode)-\(width)-\(position).png")
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let content = about.window!.contentView!
            if let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) {
                content.effectiveAppearance.performAsCurrentDrawingAppearance {
                    content.cacheDisplay(in: content.bounds, to: bitmap)
                }
                try bitmap.representation(using: .png, properties: [:])!.write(to: url)
            }
        }
    }
}
about.close()
preferences.removePersistentDomain(forName: suite)
window.close()
print("Passed: inert dial clicks, pointer jitter, drag, return drag, context click, outside release and accessibility semantics")
print("Passed: cached native rendering for \(library.catalog.themes.count) themes in both modes, saved bezel preference, preferred width and sleep pause")

print("Passed: neutral icons, grouped theme selection, all Minimalism case toggles, single-page About sections, supplied branding, light/dark layouts and scrolling")
