import AppKit

@MainActor
func checkSavedStopwatchInterface(library: ThemeLibrary) throws {
    let suite = "local.vremya.stopwatch-persistence.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.set(true, forKey: "showBezel")
    let window = ClockWindow(contentRect: NSRect(x: 100, y: 100, width: 280, height: 280), styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    defer { defaults.removePersistentDomain(forName: suite); window.close() }
    func app(_ id: String, gshock: GShock? = nil) throws -> AppDelegate {
        let renderer = try library.renderer(for: id)
        let preferences = UserDefaults(suiteName: suite)!
        let delegate = AppDelegate(library: library, renderer: renderer, defaults: preferences, gshock: gshock, signalSound: {}, buttonSound: { _ in })
        window.setContentSize(renderer.displaySize(width: 280, showBezel: true))
        let view = ClockView(renderer: renderer, hapticFeedback: { _ in })
        delegate.window = window; delegate.clockView = view; window.contentView = view
        delegate.clockMenu = delegate.makeClockMenu()
        view.onInteraction = { [weak delegate] in delegate?.performInteraction($0) }
        return delegate
    }
    func saved() throws -> SavedStopwatches { try JSONDecoder().decode(SavedStopwatches.self, from: defaults.data(forKey: "stopwatchState")!) }
    func store(_ state: SavedStopwatches) throws { defaults.set(try JSONEncoder().encode(state), forKey: "stopwatchState") }
    let past = Date().addingTimeInterval(-3600)
    var instant: TimeInterval = 0
    let first = try app("omega-speedmaster")
    first.chronograph = Chronograph(now: { instant }, wallNow: { past })
    first.toggleChronograph()
    let running = try saved()
    expect(running.analog.isRunning && running.analog.startDate == past, "Start must save the start timestamp immediately, without waiting for Quit")
    let reopened = try app("breitling-navitimer")
    expect(reopened.chronograph.isRunning && (3600...3660).contains(reopened.chronograph.reading.elapsed), "A fresh app must include its closed interval and restore the shared chronograph under another theme")
    reopened.toggleChronograph()
    let stopped = try saved()
    let olderPause = Chronograph.SavedState(elapsed: stopped.analog.elapsed, savedAt: past, startDate: stopped.analog.startDate, isRunning: false)
    try store(SavedStopwatches(analog: olderPause, chronostop: stopped.chronostop, gshock: stopped.gshock))
    let paused = try app("omega-speedmaster")
    expect(!paused.chronograph.isRunning && paused.chronograph.reading.elapsed == stopped.analog.elapsed, "A manually paused chronograph must stay frozen after hours offline")
    paused.toggleChronograph()
    let resumedState = try saved()
    expect(resumedState.analog.isRunning, "Resume must be saved immediately")
    paused.resetChronograph()
    let reset = try app("omega-speedmaster")
    expect(!reset.chronograph.isRunning && reset.chronograph.reading.elapsed == 0 && reset.chronograph.startDate == nil, "Reset must prevent a previous running checkpoint from returning")
    reset.chronograph = Chronograph(now: { instant }, wallNow: { past })
    reset.toggleChronograph(); instant += 10
    reset.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))
    let quitting = try saved()
    expect(quitting.analog.isRunning && quitting.analog.elapsed == 10, "Quit must checkpoint elapsed time without pausing it")

    defaults.removeObject(forKey: "stopwatchState"); instant = 0
    let short = try app("omega-chronostop")
    short.chronostop = Chronostop(now: { instant }, wallNow: { past })
    short.performInteraction(.chronostopPress); short.performInteraction(.chronostopRelease)
    let shortState = try saved()
    expect(shortState.chronostop.isRunning, "The first Chronostop release must save a running state")
    let shortAgain = try app("omega-chronostop")
    expect(shortAgain.chronostop.isRunning && shortAgain.chronostop.reading.elapsed >= 3600, "Chronostop must continue through relaunch")
    shortAgain.chronostopMenuAction()
    let heldValue = shortAgain.chronostop.reading.elapsed
    let heldAgain = try app("omega-chronostop")
    expect(heldAgain.chronostop.readingHeld && !heldAgain.chronostop.isRunning && heldAgain.chronostop.reading.elapsed == heldValue, "A manually held reading must remain held after relaunch")
    heldAgain.resetChronostop()
    let shortReset = try app("omega-chronostop")
    expect(!shortReset.chronostop.isRunning && !shortReset.chronostop.readingHeld && shortReset.chronostop.reading.elapsed == 0, "Chronostop reset must survive relaunch")

    defaults.removeObject(forKey: "stopwatchState"); instant = 0
    var digital = GShock(now: { instant }, wallNow: { past })
    digital.selectMode(.stopwatch)
    let digitalApp = try app("casio-gshock", gshock: digital)
    digitalApp.pressGShock(.b); instant += 12.34; digitalApp.pressGShock(.a)
    let digitalSaved = try saved()
    expect(digitalSaved.gshock.timer.isRunning && digitalSaved.gshock.split == 12.34, "G-Shock start and split must save the running timer")
    let digitalAgain = try app("casio-gshock")
    expect(digitalAgain.gshock.mode == .stopwatch && digitalAgain.gshock.stopwatchRunning && digitalAgain.gshock.stopwatchElapsed > 3612 && digitalAgain.gshock.split == 12.34,
           "G-Shock relaunch must restore the visible stopwatch, its background elapsed time and frozen split")
    digitalAgain.pressGShock(.b)
    let digitalPaused = try app("casio-gshock")
    expect(!digitalPaused.gshock.stopwatchRunning && digitalPaused.gshock.stopwatchElapsed == digitalAgain.gshock.stopwatchElapsed, "G-Shock manual Stop must survive relaunch")
    digitalPaused.pressGShock(.a); digitalPaused.pressGShock(.a)
    let digitalReset = try app("casio-gshock")
    expect(!digitalReset.gshock.stopwatchRunning && digitalReset.gshock.stopwatchElapsed == 0 && digitalReset.gshock.split == nil, "G-Shock split release and reset must clear the saved result")
    defaults.set(Data("invalid".utf8), forKey: "stopwatchState")
    let invalid = try app("omega-speedmaster")
    expect(!invalid.chronograph.isRunning && invalid.chronograph.reading.elapsed == 0, "Malformed saved state must not prevent startup")
    var future = quitting; future.version = 99; try store(future)
    let unsupported = try app("omega-speedmaster")
    expect(!unsupported.chronograph.isRunning, "An unsupported persistence version must be ignored safely")
    print("Passed: start/pause/resume/reset preferences, fresh-app restoration, original timestamps, quit checkpoints, Chronostop hold, G-Shock mode/split and corrupt-state fallback")
}
