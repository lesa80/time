import Foundation

func checkCountdownPersistence() throws {
    let base = Date(timeIntervalSince1970: 1_800_000_000)
    var wall = base
    var instant: TimeInterval = 100
    var settings = GShockSettings()
    settings.countdownSeconds = 60
    var watch = GShock(settings: settings, now: { instant }, wallNow: { wall })
    watch.selectMode(.countdown); watch.press(.b)
    instant += 12.25; wall = wall.addingTimeInterval(12.25)
    func roundTrip(_ state: GShock.CountdownState) throws -> GShock.CountdownState {
        try JSONDecoder().decode(GShock.CountdownState.self, from: JSONEncoder().encode(state))
    }
    let started = try roundTrip(watch.savedCountdown)
    close(started.remaining, 47.75, "Countdown checkpoint keeps fractional remaining time")
    precondition(started.isRunning && started.wasVisible)
    wall = wall.addingTimeInterval(20); instant = 0 // new process or a reboot
    let restored = GShock(settings: settings, now: { instant }, wallNow: { wall }, restoringCountdown: started)
    precondition(restored.mode == .countdown && restored.countdownRunning && restored.needsService)
    close(restored.remaining, 27.75, "A relaunch deducts the closed interval")
    instant += 2.5
    close(restored.remaining, 25.25, "Restored countdown continues on a new monotonic clock")
    wall = wall.addingTimeInterval(3600)
    close(restored.remaining, 25.25, "Active wall-clock changes must not alter the countdown")
    let rebased = restored.savedCountdown
    wall = wall.addingTimeInterval(5)
    var next = GShock(settings: settings, now: { instant }, wallNow: { wall }, restoringCountdown: rebased)
    close(next.remaining, 20.25, "A checkpoint rebases a changed system clock")
    next.press(.b)
    let paused = try roundTrip(next.savedCountdown)
    wall = wall.addingTimeInterval(86400)
    var frozen = GShock(settings: settings, now: { instant }, wallNow: { wall }, restoringCountdown: paused)
    precondition(!frozen.countdownRunning)
    close(frozen.remaining, 20.25, "Manual pause survives a day offline")
    frozen.press(.b); instant += 2
    close(frozen.remaining, 18.25, "Resume excludes the paused interval")
    frozen.press(.b); frozen.press(.a)
    let reset = GShock(settings: settings, now: { instant }, wallNow: { wall }, restoringCountdown: frozen.savedCountdown)
    precondition(!reset.countdownRunning && reset.remaining == 60)

    wall = started.savedAt.addingTimeInterval(1000)
    var overdue = GShock(settings: settings, now: { instant }, wallNow: { wall }, restoringCountdown: started)
    precondition(overdue.countdownRunning && overdue.remaining == 0 && !overdue.isRinging)
    precondition(overdue.tick(date: wall) == .countdown && overdue.isRinging && !overdue.countdownRunning)
    precondition(overdue.tick(date: wall) == nil, "A missed deadline creates only one event")
    let acknowledged = try roundTrip(overdue.savedCountdown)
    var acknowledgedAgain = GShock(settings: settings, now: { instant }, wallNow: { wall }, restoringCountdown: acknowledged)
    precondition(acknowledgedAgain.tick(date: wall) == nil && !acknowledgedAgain.isRinging && !acknowledgedAgain.countdownRunning)
    close(acknowledgedAgain.remaining, 60, "An acknowledged one-shot is ready for a fresh run")
    acknowledgedAgain.press(.b)
    close(acknowledgedAgain.remaining, 60, "A completed timer restarts at its configured duration")

    // Quit before tick handles expiry: negative time must survive another checkpoint.
    wall = base; instant = 0
    settings.countdownSeconds = 10; settings.autoRepeat = true
    var repeated = GShock(settings: settings, now: { instant }, wallNow: { wall })
    repeated.selectMode(.countdown); repeated.press(.b)
    instant = 26; wall = wall.addingTimeInterval(26)
    let lateCheckpoint = try roundTrip(repeated.savedCountdown)
    close(lateCheckpoint.remaining, -16, "Overdue snapshots keep missed-cycle phase")
    wall = wall.addingTimeInterval(7); instant = 0
    var repeatAgain = GShock(settings: settings, now: { instant }, wallNow: { wall }, restoringCountdown: lateCheckpoint)
    precondition(repeatAgain.tick(date: wall) == .countdown && repeatAgain.countdownRunning)
    close(repeatAgain.remaining, 7, "Auto-repeat retains phase across missed cycles and relaunches")
    precondition(repeatAgain.tick(date: wall) == nil)
    let consumed = try roundTrip(repeatAgain.savedCountdown)
    wall = wall.addingTimeInterval(2)
    var repeatNext = GShock(settings: settings, now: { instant }, wallNow: { wall }, restoringCountdown: consumed)
    precondition(repeatNext.tick(date: wall) == nil, "Relaunching before the next deadline must not replay its signal")
    close(repeatNext.remaining, 5, "Restored repeated timer stays in the same cycle")
    repeatNext.press(.b)
    let repeatPaused = repeatNext.savedCountdown
    wall = wall.addingTimeInterval(1000)
    var repeatResume = GShock(settings: settings, now: { instant }, wallNow: { wall }, restoringCountdown: repeatPaused)
    close(repeatResume.remaining, 5, "Auto-repeat also preserves a manual pause")
    repeatResume.press(.b); instant += 7
    precondition(repeatResume.tick(date: wall) == .countdown)
    close(repeatResume.remaining, 8, "A partial resumed cycle returns to full repeated cycles")

    wall = started.savedAt.addingTimeInterval(-60)
    settings.countdownSeconds = 60; settings.autoRepeat = false
    let rollback = GShock(settings: settings, now: { instant }, wallNow: { wall }, restoringCountdown: started)
    close(rollback.remaining, started.remaining, "A backwards closed-interval clock adjustment must not add timer time")
    for bad in [
        GShock.CountdownState(version: 99, duration: 60, autoRepeat: false, remaining: 10, savedAt: base, isRunning: true, wasVisible: true),
        GShock.CountdownState(duration: 0, autoRepeat: false, remaining: 0, savedAt: base, isRunning: true, wasVisible: true),
        GShock.CountdownState(duration: 60, autoRepeat: false, remaining: 61, savedAt: base, isRunning: true, wasVisible: true),
        GShock.CountdownState(duration: 60, autoRepeat: false, remaining: -1, savedAt: base, isRunning: false, wasVisible: true),
        GShock.CountdownState(duration: 60, autoRepeat: false, remaining: .infinity, savedAt: base, isRunning: true, wasVisible: true),
        GShock.CountdownState(duration: 60, autoRepeat: false, remaining: 10, savedAt: Date(timeIntervalSinceReferenceDate: .nan), isRunning: true, wasVisible: true),
        GShock.CountdownState(duration: 10, autoRepeat: false, remaining: 5, savedAt: base, isRunning: true, wasVisible: true),
        GShock.CountdownState(duration: 60, autoRepeat: true, remaining: 5, savedAt: base, isRunning: true, wasVisible: true)
    ] {
        let safe = GShock(settings: settings, now: { instant }, wallNow: { wall }, restoringCountdown: bad)
        precondition(!safe.countdownRunning && safe.remaining == 60 && safe.mode == .time,
                     "Invalid or mismatched countdown state must be ignored safely")
    }
    print("Passed: countdown JSON persistence, closed/reboot gaps, pause/resume/reset, monotonic measurement, overdue single alert, acknowledged completion, auto-repeat phase and invalid-state fallback")
}
