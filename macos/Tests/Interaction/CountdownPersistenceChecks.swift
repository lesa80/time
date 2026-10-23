import AppKit

@MainActor
func checkSavedCountdownInterface(library: ThemeLibrary) throws {
    let suite = "local.vremya.countdown-persistence.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.set(true, forKey: "showBezel")
    let window = ClockWindow(contentRect: NSRect(x: 100, y: 100, width: 280, height: 280), styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    var delegates: [AppDelegate] = []
    var sounds = 0
    defer {
        for delegate in delegates { delegate.timer?.invalidate(); delegate.gshockServiceTimer?.invalidate() }
        defaults.removePersistentDomain(forName: suite); window.close()
    }
    func app(_ id: String = "casio-gshock", gshock: GShock? = nil) throws -> AppDelegate {
        let renderer = try library.renderer(for: id)
        let delegate = AppDelegate(library: library, renderer: renderer, defaults: UserDefaults(suiteName: suite)!, gshock: gshock,
                                   signalSound: { sounds += 1 }, buttonSound: { _ in })
        let view = ClockView(renderer: renderer, hapticFeedback: { _ in })
        window.setContentSize(renderer.displaySize(width: 280, showBezel: true))
        delegate.window = window; delegate.clockView = view; window.contentView = view
        delegate.clockMenu = delegate.makeClockMenu()
        view.onInteraction = { [weak delegate] in delegate?.performInteraction($0) }
        delegates.append(delegate)
        return delegate
    }
    func saved() throws -> SavedStopwatches { try JSONDecoder().decode(SavedStopwatches.self, from: defaults.data(forKey: "stopwatchState")!) }
    func store(_ state: SavedStopwatches) throws { defaults.set(try JSONEncoder().encode(state), forKey: "stopwatchState") }
    var instant: TimeInterval = 0
    var wall = Date().addingTimeInterval(-30)
    let first = try app(gshock: GShock(now: { instant }, wallNow: { wall }))
    var settings = GShockSettings(); settings.countdownSeconds = 120
    first.applyGShockSettings(settings)
    let countdownItem = first.menuActions["gshockModes"]!.submenu!.items[2]
    first.selectGShockMode(countdownItem)
    first.performInteraction(.gshockB)
    let running = try saved().countdown!
    expect(running.isRunning && running.remaining == 120 && running.wasVisible, "The mechanical Start action must save the countdown immediately")
    let reopened = try app()
    expect(reopened.gshock.mode == .countdown && reopened.gshock.countdownRunning && (88...91).contains(reopened.gshock.remaining),
           "A fresh app must restore the visible countdown and subtract its closed interval")
    let checkpoint = defaults.data(forKey: "stopwatchState")!
    reopened.advanceGShock(date: Date())
    expect(checkpoint == defaults.data(forKey: "stopwatchState"), "Normal refresh ticks must not write preferences")
    reopened.pressGShock(.b)
    var paused = try saved()
    let frozenValue = paused.countdown!.remaining
    paused.countdown = GShock.CountdownState(duration: 120, autoRepeat: false, remaining: frozenValue,
                                            savedAt: Date().addingTimeInterval(-86400), isRunning: false, wasVisible: true)
    try store(paused)
    let frozen = try app()
    expect(!frozen.gshock.countdownRunning && frozen.gshock.remaining == frozenValue, "A manually paused countdown must stay frozen across launches")
    frozen.pressGShock(.b)
    let resumed = try saved()
    expect(resumed.countdown!.isRunning, "Resume must be persisted immediately")
    frozen.pressGShock(.b); frozen.pressGShock(.a)
    let reset = try app()
    expect(!reset.gshock.countdownRunning && reset.gshock.remaining == 120, "Reset must prevent a stale countdown from returning")

    instant = 0; wall = Date().addingTimeInterval(-30)
    let quitting = try app(gshock: GShock(settings: settings, now: { instant }, wallNow: { wall }))
    quitting.gshock.selectMode(.countdown); quitting.pressGShock(.b)
    instant += 4; wall = wall.addingTimeInterval(4)
    quitting.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
    let quitState = try saved().countdown!
    expect(quitState.isRunning && quitState.remaining == 116, "Quit must checkpoint remaining time without stopping the countdown")
    let afterQuit = try app()
    expect(afterQuit.gshock.countdownRunning && (88...91).contains(afterQuit.gshock.remaining), "Quit restoration must deduct time exactly once")

    instant = 0; wall = Date().addingTimeInterval(-7200)
    settings.countdownSeconds = 2
    let overdueSource = try app(gshock: GShock(settings: settings, now: { instant }, wallNow: { wall }))
    overdueSource.gshock.selectMode(.countdown); overdueSource.pressGShock(.b)
    // A restored timer must be serviced even when a different theme is selected.
    let overdue = try app("minimalism")
    sounds = 0
    overdue.advanceGShock(date: Date())
    expect(sounds == 1 && overdue.gshock.isRinging && !overdue.gshock.countdownRunning,
           "An overdue restored countdown must sound on launch under any theme")
    let consumed = try saved()
    expect(consumed.countdown!.isRunning == false, "The consumed deadline must be saved before sound delivery")
    overdue.advanceGShock(date: Date())
    expect(sounds == 1, "Missed countdowns must not create a burst of sounds")
    let acknowledged = try app()
    acknowledged.advanceGShock(date: Date())
    expect(sounds == 1 && !acknowledged.gshock.isRinging && acknowledged.gshock.remaining == 2,
           "A consumed one-shot must not replay after another immediate relaunch")

    instant = 0; wall = Date().addingTimeInterval(-25)
    settings.countdownSeconds = 10; settings.autoRepeat = true
    let repeatedSource = try app(gshock: GShock(settings: settings, now: { instant }, wallNow: { wall }))
    repeatedSource.gshock.selectMode(.countdown); repeatedSource.pressGShock(.b)
    let repeated = try app()
    sounds = 0; repeated.advanceGShock(date: Date())
    expect(sounds == 1 && repeated.gshock.countdownRunning && (3...6).contains(repeated.gshock.remaining),
           "Offline auto-repeat must emit one alert while retaining the current cycle phase")
    let repeatedAgain = try app()
    repeatedAgain.advanceGShock(date: Date())
    expect(sounds == 1 && repeatedAgain.gshock.countdownRunning && (3...6).contains(repeatedAgain.gshock.remaining),
           "A saved repeat boundary must not be replayed before the next cycle")
    repeatedAgain.silenceGShock(); repeatedAgain.pressGShock(.b)
    var changed = repeatedAgain.gshock.settings; changed.countdownSeconds = 20
    repeatedAgain.applyGShockSettings(changed)
    let reconfigured = try app()
    expect(!reconfigured.gshock.countdownRunning && reconfigured.gshock.remaining == 20,
           "A new countdown duration must clear the old saved measurement")

    // Upgrade from 2.9.1: no countdown field must leave existing stopwatch data intact.
    let current = try saved()
    var legacy = SavedStopwatches(analog: Chronograph.SavedState(elapsed: 5, savedAt: Date(), startDate: Date(), isRunning: false),
                                 chronostop: current.chronostop, gshock: current.gshock)
    try store(legacy)
    let dictionary = try JSONSerialization.jsonObject(with: defaults.data(forKey: "stopwatchState")!) as! [String: Any]
    expect(dictionary["countdown"] == nil, "The migration fixture must match the 2.9.1 schema")
    let upgraded = try app()
    expect(upgraded.chronograph.reading.elapsed == 5 && !upgraded.gshock.countdownRunning && upgraded.gshock.remaining == 20,
           "Old preferences must keep stopwatch data and initialize an idle countdown")
    legacy.countdown = GShock.CountdownState(version: 99, duration: 20, autoRepeat: true, remaining: 5,
                                            savedAt: Date(), isRunning: true, wasVisible: true)
    try store(legacy)
    let invalid = try app()
    expect(invalid.chronograph.reading.elapsed == 5 && !invalid.gshock.countdownRunning && invalid.gshock.remaining == 20,
           "An unsupported countdown checkpoint must not discard other saved timers")
    print("Passed: countdown action/lifecycle preferences, new-app restoration, no per-frame writes, pause/reset, overdue background sound consumed once, repeat phase, settings reset and 2.9.1 migration")
}
