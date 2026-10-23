import AppKit
import ImageIO

@MainActor
func checkGShockInterface(library: ThemeLibrary) throws {
    try checkGShockButtonSound(library: library)
    let renderer = try library.renderer(for: "casio-gshock")
    let suite = "local.vremya.gshock-tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.set(280, forKey: "diameter")
    defaults.set(true, forKey: "showBezel")
    var now: TimeInterval = 0
    var sounds = 0
    let delegate = AppDelegate(library: library, renderer: renderer, defaults: defaults,
        gshock: GShock(now: { now }), signalSound: { sounds += 1 }, buttonSound: { _ in })
    let window = ClockWindow(contentRect: NSRect(origin: .zero, size: renderer.displaySize(width: 280, showBezel: true)),
                             styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    let view = ClockView(renderer: renderer, hapticFeedback: { _ in })
    window.contentView = view
    delegate.window = window
    delegate.clockView = view
    view.onInteraction = { [weak delegate] in delegate?.performInteraction($0) }
    defer {
        view.endPointerHover()
        delegate.timer?.invalidate(); delegate.gshockServiceTimer?.invalidate()
        defaults.removePersistentDomain(forName: suite)
        window.close()
    }
    let menu = delegate.makeClockMenu()
    delegate.menuNeedsUpdate(menu)
    expect(!delegate.menuActions["interaction"]!.isHidden && delegate.menuActions["chronoToggle"]!.isHidden,
           "G-Shock must expose only its own interactions immediately after the model title")
    let modes = delegate.menuActions["gshockModes"]!.submenu!
    let buttons = view.subviews.compactMap { $0 as? MechanicalButton }
    expect(buttons.count == 4, "G-Shock needs all four mechanical controls")
    for width: CGFloat in [180, 280, 466] {
        window.setContentSize(renderer.displaySize(width: width, showBezel: true))
        view.layoutSubtreeIfNeeded()
        for button in buttons {
            expect(button.isEnabled && !button.isHidden && button.accessibilityRole() == .button,
                   "Each pusher must be enabled and accessible: \(button.control.action), enabled=\(button.isEnabled), hidden=\(button.isHidden), role=\(String(describing: button.accessibilityRole()))")
            expect(view.hitTest(NSPoint(x: button.frame.midX, y: button.frame.midY)) === button,
                   "The pusher hit area must follow the photographed button at every size")
        }
    }
    modes.performActionForItem(at: 3)
    let b = buttons.first { $0.control.action == .gshockB }!
    let a = buttons.first { $0.control.action == .gshockA }!
    b.performClick(nil)
    now += 15.25
    delegate.updateClock()
    expect(delegate.gshock.stopwatchRunning && view.gshockDisplay?.fields["seconds"] == "25",
           "The actual B pusher must start centisecond stopwatch output")
    a.performClick(nil)
    now += 4
    delegate.updateClock()
    expect(view.gshockDisplay?.fields["minutes"] == "15", "The actual A pusher must freeze a split")
    let controls = delegate.menuActions["gshockB"]!.menu!
    controls.performActionForItem(at: controls.index(of: delegate.menuActions["gshockB"]!))
    a.performClick(nil); a.performClick(nil)
    expect(!delegate.gshock.stopwatchRunning && delegate.gshock.stopwatchElapsed == 0,
           "Menu pause and pusher reset must control the same stopwatch")
    view.showBezel = false
    expect(buttons.allSatisfy(\.isHidden), "Dial-only mode must hide all physical G-Shock hit areas")
    controls.performActionForItem(at: controls.index(of: delegate.menuActions["gshockB"]!))
    expect(delegate.gshock.stopwatchRunning, "G-Shock menu actions must remain available without a case")
    var settings = delegate.gshock.settings
    settings.countdownSeconds = 2; settings.use24Hour = false
    delegate.applyGShockSettings(settings)
    modes.performActionForItem(at: 2)
    delegate.pressGShock(.b)
    delegate.renderer = try library.renderer(for: "minimalism")
    view.renderer = delegate.renderer
    now += 3
    delegate.advanceGShock(date: Date())
    expect(sounds == 1 && delegate.gshock.isRinging, "Countdown must sound while another theme is selected")
    delegate.menuNeedsUpdate(menu)
    expect(!delegate.menuActions["interaction"]!.isHidden && !delegate.menuActions["gshockSilence"]!.isHidden,
           "A background G-Shock alarm must expose a stop action from any selected theme")
    controls.performActionForItem(at: controls.index(of: delegate.menuActions["gshockSilence"]!))
    expect(!delegate.gshock.isRinging && delegate.menuActions["interaction"]!.isHidden,
           "Stopping the background alert must silence it and restore the normal theme menu")
    let reloaded = AppDelegate(library: library, renderer: renderer, defaults: UserDefaults(suiteName: suite)!, signalSound: {})
    expect(!reloaded.gshock.settings.use24Hour && reloaded.gshock.settings.countdownSeconds == 2,
           "G-Shock settings must persist independently of the selected theme")
    expect(!reloaded.gshock.countdownRunning && reloaded.gshock.stopwatchRunning &&
           reloaded.gshock.stopwatchElapsed >= delegate.gshock.stopwatchElapsed,
           "A running stopwatch must resume after relaunch; a completed, silenced countdown must stay stopped")

    let alarmForm = GShockSettingsForm(settings: GShockSettings(), alarm: true)
    expect(alarmForm.fields.count == 4 && alarmForm.view.fittingSize.width > 200,
           "Alarm settings form must provide usable hour, minute, month and day controls")
    alarmForm.fields[2].selectItem(at: 2); alarmForm.fields[3].selectItem(at: 30)
    expect(alarmForm.selectedSettings == nil, "Alarm form must reject impossible month/day combinations")
    alarmForm.fields[3].selectItem(at: 29)
    expect(alarmForm.selectedSettings?.alarmEnabled == true, "A valid alarm configuration must enable the alarm")
    let timerForm = GShockSettingsForm(settings: GShockSettings(), alarm: false)
    timerForm.fields[0].selectItem(at: 24); timerForm.fields[1].selectItem(at: 1)
    expect(timerForm.selectedSettings == nil, "Timer form must reject values above 24 hours")
    timerForm.fields[1].selectItem(at: 0); timerForm.fields[2].selectItem(at: 0)
    expect(timerForm.selectedSettings?.countdownSeconds == 86_400, "24-hour countdown must be representable")

    delegate.renderer = renderer; view.renderer = renderer; view.showBezel = true
    modes.performActionForItem(at: 0)
    let point = b.convert(NSPoint(x: b.bounds.midX, y: b.bounds.midY), to: nil)
    // A separate pusher proves release/hold semantics without posting system events or playing sounds.
    var shortPresses = 0, longPresses = 0
    let probe = MechanicalButton(control: b.control, hapticFeedback: { _ in }) { shortPresses += 1 }
    probe.onLongPress = { longPresses += 1 }
    probe.frame = b.frame
    view.addSubview(probe)
    func pointer(_ type: NSEvent.EventType, at point: NSPoint) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: point, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                           context: nil, eventNumber: 0, clickCount: 1, pressure: 0)!
    }
    let probePoint = probe.convert(NSPoint(x: probe.bounds.midX, y: probe.bounds.midY), to: nil)
    probe.mouseDown(with: pointer(.leftMouseDown, at: probePoint))
    probe.mouseUp(with: pointer(.leftMouseUp, at: probePoint))
    expect(shortPresses == 1 && longPresses == 0, "A short release must invoke only the normal pusher action")
    probe.mouseDown(with: pointer(.leftMouseDown, at: probePoint))
    RunLoop.main.run(until: Date().addingTimeInterval(2.1))
    probe.mouseUp(with: pointer(.leftMouseUp, at: probePoint))
    expect(shortPresses == 1 && longPresses == 1, "Holding B must invoke one long action without a short action on release")
    probe.mouseDown(with: pointer(.leftMouseDown, at: probePoint))
    probe.mouseDragged(with: pointer(.leftMouseDragged, at: NSPoint(x: point.x + 500, y: point.y)))
    probe.mouseUp(with: pointer(.leftMouseUp, at: probePoint))
    expect(shortPresses == 1 && longPresses == 1, "Dragging off a pusher must cancel the press")
    probe.removeFromSuperview()

    let date = ISO8601DateFormatter().date(from: "2026-10-19T13:42:21Z")!
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    var watch = GShock(now: { now })
    let angles = HandAngles(date: date, calendar: calendar)
    let preview = URL(fileURLWithPath: "macos/.build/previews")
    try FileManager.default.createDirectory(at: preview, withIntermediateDirectories: true)
    for mode in GShock.Mode.allCases {
        watch.selectMode(mode)
        let data = try renderer.png(side: 466, angles: angles, gshock: watch.display(date: date, calendar: calendar))
        try data.write(to: preview.appendingPathComponent("gshock-\(mode.rawValue).png"))
    }
    watch.selectMode(.time); watch.press(.d)
    let lit = watch.display(date: date, calendar: calendar)
    try renderer.png(side: 466, angles: angles, gshock: lit).write(to: preview.appendingPathComponent("gshock-light.png"))
    for showBezel in [true, false] {
        let size = renderer.displaySize(width: 400, showBezel: showBezel)
        func render(cached: Bool, reading: GShockDisplay) -> Data {
            let bitmap = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                bytesPerRow: Int(size.width) * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            for pass: DialRenderer.DrawingPass in cached ? [.background, .live, .foreground] : [.all] {
                renderer.draw(in: bitmap, size: size, angles: angles, showBezel: showBezel, pass: pass, gshock: reading)
            }
            return Data(bytes: bitmap.data!, count: Int(size.width * size.height) * 4)
        }
        watch.selectMode(.stopwatch); watch.press(.b); now += 17.25
        let moving = watch.display(date: date, calendar: calendar)
        expect(render(cached: true, reading: moving) == render(cached: false, reading: moving),
               "Cached digital output must agree with the direct renderer in both case modes")
        expect(render(cached: false, reading: moving) != render(cached: false, reading: lit),
               "Live mode fields and backlight must visibly change the LCD")
    }
    print("Passed: G-Shock mechanical/menu controls, split, saved forms, background alarm, long press and cached LCD/backlight rendering")
}

@MainActor
private func checkGShockButtonSound(library: ThemeLibrary) throws {
    let renderer = try library.renderer(for: "casio-gshock")
    let suite = "local.vremya.button-sound-tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.set(280, forKey: "diameter")
    var now: TimeInterval = 0
    var beeps = 0, signals = 0
    var volumes: [Float] = []
    let delegate = AppDelegate(library: library, renderer: renderer, defaults: defaults,
        gshock: GShock(now: { now }), signalSound: { signals += 1 }, buttonSound: { volume in beeps += 1; volumes.append(volume) })
    let size = renderer.displaySize(width: 280, showBezel: true)
    let window = ClockWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    let view = ClockView(renderer: renderer, hapticFeedback: { _ in })
    window.contentView = view
    delegate.window = window; delegate.clockView = view
    view.onInteraction = { [weak delegate] in delegate?.performInteraction($0) }
    defer {
        view.endPointerHover()
        delegate.timer?.invalidate(); delegate.gshockServiceTimer?.invalidate()
        defaults.removePersistentDomain(forName: suite)
        window.close()
    }
    let menu = delegate.makeClockMenu()
    delegate.menuNeedsUpdate(menu)
    expect(delegate.gshockButtonSoundEnabled && delegate.menuActions["gshockButtonSound"]?.state == .on,
           "Button sound must be enabled for a fresh installation without resetting existing G-Shock preferences")
    let tone = AppDelegate.makeGShockButtonSound(resources: library.resources)
    expect(tone != nil && abs(tone!.duration - 0.08) < 0.001, "The app must bundle a decodable short button tone")
    expect(delegate.gshockButtonVolume == 1 &&
           delegate.menuActions["gshockButtonVolume"]?.action == #selector(AppDelegate.configureGShockButtonVolume),
           "Existing installations must retain full button volume and expose the volume settings action")
    let volumeForm = GShockButtonVolumeForm(volume: 0.42)
    expect(volumeForm.readout.stringValue == "42%" && volumeForm.slider.minValue == 0 &&
           volumeForm.slider.maxValue == 100 && volumeForm.slider.accessibilityLabel() == L("Button volume") &&
           volumeForm.view.fittingSize.width >= 278, "The volume form must provide a labeled 0–100 percent slider")
    volumeForm.slider.doubleValue = 73.4
    volumeForm.slider.sendAction(volumeForm.slider.action, to: volumeForm.slider.target)
    expect(volumeForm.volume == 0.73 && volumeForm.readout.stringValue == "73%" && delegate.gshockButtonVolume == 1,
           "Changing the dialog must update its percentage without saving before confirmation")
    delegate.setGShockButtonVolume(volumeForm.volume)
    delegate.pressGShock(.b)
    expect(volumes.last == 0.73, "The playback callback must receive the saved button volume")
    let volumeReloaded = AppDelegate(library: library, renderer: renderer,
        defaults: UserDefaults(suiteName: suite)!, buttonSound: { _ in })
    expect(volumeReloaded.gshockButtonVolume == 0.73, "Button volume must survive relaunch independently of mute")
    delegate.setGShockButtonVolume(0)
    let beforeZero = beeps
    delegate.pressGShock(.b)
    expect(beeps == beforeZero && delegate.gshockButtonSoundEnabled,
           "Zero volume must suppress playback without changing the separate sound switch")
    delegate.setGShockButtonVolume(-1)
    expect(delegate.gshockButtonVolume == 0, "Negative volume must clamp to silence")
    delegate.setGShockButtonVolume(2)
    delegate.setGShockButtonVolume(.nan)
    expect(delegate.gshockButtonVolume == 1, "Volume must clamp to full scale and reject non-finite values")
    defaults.set(5, forKey: "gshockButtonVolume")
    expect(delegate.gshockButtonVolume == 1, "Corrupt stored volume must never exceed NSSound's valid range")
    delegate.setGShockButtonVolume(0.73)
    let buttons = view.subviews.compactMap { $0 as? MechanicalButton }
    view.layoutSubtreeIfNeeded()
    for button in buttons {
        delegate.gshock.selectMode(.time)
        let before = beeps
        button.performClick(nil)
        expect(beeps == before + 1, "Each G-Shock pusher must request exactly one button sound")
    }
    let b = buttons.first { $0.control.action == .gshockB }!
    let point = b.convert(NSPoint(x: b.bounds.midX, y: b.bounds.midY), to: nil)
    let entered = NSEvent.enterExitEvent(with: .mouseEntered, location: point, modifierFlags: [], timestamp: 0,
        windowNumber: window.windowNumber, context: nil, eventNumber: 0, trackingNumber: 0, userData: nil)!
    let beforeHover = beeps
    b.mouseEntered(with: entered)
    expect(beeps == beforeHover, "Hover must not play button sounds")
    let modes = delegate.menuActions["gshockModes"]!.submenu!
    modes.performActionForItem(at: 3)
    expect(beeps == beforeHover + 1, "Mode selection through Interaction must provide the same sound feedback")
    let beforeNoOp = beeps
    delegate.pressGShock(.b, long: true)
    let invalid = NSMenuItem(); invalid.representedObject = "invalid-mode"
    delegate.selectGShockMode(invalid)
    expect(beeps == beforeNoOp, "Invalid mode actions and unsupported long presses must stay silent")
    let options = delegate.menuActions["gshockButtonSound"]!.menu!
    let mute = delegate.menuActions["gshockButtonSound"]!
    options.performActionForItem(at: options.index(of: mute))
    expect(!delegate.gshockButtonSoundEnabled && mute.state == .off && beeps == beforeNoOp,
           "Muting must immediately update its checkmark without playing a sound")
    let reloaded = AppDelegate(library: library, renderer: renderer, defaults: UserDefaults(suiteName: suite)!, buttonSound: { _ in })
    expect(!reloaded.gshockButtonSoundEnabled && reloaded.gshockButtonVolume == 0.73,
           "Mute must survive app relaunch without discarding the chosen volume")
    for button in buttons { button.performClick(nil) }
    delegate.gshock.selectMode(.time)
    delegate.performInteraction(.gshockFlash)
    modes.performActionForItem(at: 2)
    expect(beeps == beforeNoOp, "Muted pushers, long actions and menu mode changes must stay silent")
    var settings = delegate.gshock.settings
    settings.countdownSeconds = 2; settings.alarmHour = 11; settings.alarmMinute = 42
    delegate.applyGShockSettings(settings)
    expect(beeps == beforeNoOp, "Applying settings must not produce button feedback")
    let savedSettings = delegate.gshock.settings
    delegate.pressGShock(.b)
    now += 3
    delegate.advanceGShock(date: Date())
    expect(signals == 1 && delegate.gshock.isRinging && beeps == beforeNoOp,
           "Muting button sound must not mute the countdown alarm")
    options.performActionForItem(at: options.index(of: mute))
    let savedAfterToggle = defaults.data(forKey: "gshockSettings").flatMap { try? JSONDecoder().decode(GShockSettings.self, from: $0) }
    expect(savedAfterToggle == savedSettings,
           "The separate sound preference must preserve the existing alarm/timer settings schema")
    delegate.lastGShockSoundAt = .distantPast
    delegate.pressGShock(.a)
    expect(!delegate.gshock.isRinging && signals == 1 && beeps == beforeNoOp,
           "Silencing a ringing alert must neither replay the alert nor add a button beep")
    let restored = AppDelegate(library: library, renderer: renderer, defaults: UserDefaults(suiteName: suite)!, buttonSound: { _ in })
    expect(restored.gshockButtonSoundEnabled && restored.gshock.settings.alarmHour == 11 &&
           restored.gshock.settings.alarmMinute == 42, "Sound and legacy G-Shock settings must both restore correctly")
    delegate.gshock.selectMode(.time)
    func pointer(_ type: NSEvent.EventType, _ location: NSPoint) -> NSEvent {
        NSEvent.mouseEvent(with: type, location: location, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                           context: nil, eventNumber: 0, clickCount: 1, pressure: 0)!
    }
    let beforeHold = beeps
    b.mouseDown(with: pointer(.leftMouseDown, point))
    RunLoop.main.run(until: Date().addingTimeInterval(2.1))
    b.mouseUp(with: pointer(.leftMouseUp, point))
    expect(beeps == beforeHold + 1, "Long B must beep once without a second beep on release")
    b.mouseDown(with: pointer(.leftMouseDown, point))
    b.mouseDragged(with: pointer(.leftMouseDragged, NSPoint(x: point.x + 500, y: point.y)))
    b.mouseUp(with: pointer(.leftMouseUp, point))
    expect(beeps == beforeHold + 1, "A cancelled drag must not play a sound")
    delegate.renderer = try library.renderer(for: "minimalism")
    delegate.performInteraction(.gshockA)
    expect(beeps == beforeHold + 1, "Other themes must not trigger G-Shock button audio")
    print("Passed: bundled button tone, saved 0–100% volume, accessible slider, one beep per pusher/menu/hold, saved mute, silent hover/cancel and independent alarm sound")
}
