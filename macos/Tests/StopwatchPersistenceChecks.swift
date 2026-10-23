import Foundation

func checkStopwatchPersistence() throws {
    let base = Date(timeIntervalSince1970: 1_800_000_000)
    var wall = base
    var instant: TimeInterval = 100
    var watch = Chronograph(now: { instant }, wallNow: { wall })
    watch.start(); watch.start()
    precondition(watch.startDate == base)
    instant += 12.25; wall = wall.addingTimeInterval(12.25)
    let snapshot = try JSONDecoder().decode(Chronograph.SavedState.self, from: JSONEncoder().encode(watch.savedState))
    precondition(snapshot.elapsed == 12.25 && snapshot.isRunning && snapshot.startDate == base)
    wall = wall.addingTimeInterval(3600)
    instant = 0 // a new process or a reboot has a different continuous-clock origin
    var restored = Chronograph(now: { instant }, wallNow: { wall }, restoring: snapshot)
    precondition(restored.isRunning && restored.reading.elapsed == 3612.25 && restored.startDate == base)
    instant += 1.75
    precondition(restored.reading.elapsed == 3614)
    restored.pause()
    let paused = restored.savedState
    wall = wall.addingTimeInterval(86400)
    var frozen = Chronograph(now: { instant }, wallNow: { wall }, restoring: paused)
    precondition(!frozen.isRunning && frozen.reading.elapsed == 3614 && frozen.startDate == base)
    frozen.start(); instant += 5
    precondition(frozen.reading.elapsed == 3619 && frozen.startDate == base)
    // Changing wall time in the active process must not change elapsed time.
    wall = wall.addingTimeInterval(-7200)
    precondition(frozen.reading.elapsed == 3619)
    let rebased = frozen.savedState
    wall = wall.addingTimeInterval(60)
    var next = Chronograph(now: { instant }, wallNow: { wall }, restoring: rebased)
    precondition(next.reading.elapsed == 3679 && next.isRunning)
    next.reset()
    let reset = next.savedState
    wall = wall.addingTimeInterval(100000)
    let cleared = Chronograph(now: { instant }, wallNow: { wall }, restoring: reset)
    precondition(!cleared.isRunning && cleared.reading.elapsed == 0 && cleared.startDate == nil)
    wall = rebased.savedAt.addingTimeInterval(-60)
    let rollback = Chronograph(now: { instant }, wallNow: { wall }, restoring: rebased)
    precondition(rollback.isRunning && rollback.reading.elapsed == rebased.elapsed, "A backward clock adjustment between launches must not subtract elapsed time")
    for bad in [
        Chronograph.SavedState(version: 99, elapsed: 5, savedAt: base, startDate: base, isRunning: true),
        Chronograph.SavedState(elapsed: -1, savedAt: base, startDate: base, isRunning: true),
        Chronograph.SavedState(elapsed: .infinity, savedAt: base, startDate: base, isRunning: true),
        Chronograph.SavedState(elapsed: 10, savedAt: base, startDate: nil, isRunning: true)
    ] {
        let safe = Chronograph(now: { instant }, wallNow: { wall }, restoring: bad)
        precondition(!safe.isRunning && safe.reading.elapsed == 0)
    }

    wall = base; instant = 0
    var stop = Chronostop(now: { instant }, wallNow: { wall })
    stop.press(); stop.release(); instant += 5; wall = wall.addingTimeInterval(5)
    let runningStop = stop.savedState
    wall = wall.addingTimeInterval(3600)
    var restoredStop = Chronostop(now: { instant }, wallNow: { wall }, restoring: runningStop)
    precondition(restoredStop.isRunning && restoredStop.reading.elapsed == 3605)
    restoredStop.read()
    let heldStop = restoredStop.savedState
    wall = wall.addingTimeInterval(600)
    var held = Chronostop(now: { instant }, wallNow: { wall }, restoring: heldStop)
    precondition(held.readingHeld && !held.isRunning && held.reading.elapsed == 3605)
    held.release()
    let empty = Chronostop(now: { instant }, wallNow: { wall }, restoring: held.savedState)
    precondition(!empty.readingHeld && !empty.isRunning && empty.reading.elapsed == 0)

    wall = base; instant = 0
    var digital = GShock(now: { instant }, wallNow: { wall })
    digital.selectMode(.stopwatch); digital.press(.b)
    instant += 12.34; wall = wall.addingTimeInterval(12.34); digital.press(.a)
    let split = try JSONDecoder().decode(GShock.StopwatchState.self, from: JSONEncoder().encode(digital.savedStopwatch))
    wall = wall.addingTimeInterval(3600)
    var digitalRestored = GShock(now: { instant }, wallNow: { wall }, restoringStopwatch: split)
    precondition(digitalRestored.mode == .stopwatch && digitalRestored.stopwatchRunning)
    precondition(abs(digitalRestored.stopwatchElapsed - 3612.34) < 0.001 && digitalRestored.split == 12.34)
    digitalRestored.press(.b)
    let stopped = digitalRestored.savedStopwatch
    wall = wall.addingTimeInterval(600)
    var digitalPaused = GShock(now: { instant }, wallNow: { wall }, restoringStopwatch: stopped)
    precondition(!digitalPaused.stopwatchRunning && digitalPaused.stopwatchElapsed == stopped.timer.elapsed && digitalPaused.split == 12.34)
    digitalPaused.press(.a); digitalPaused.press(.a)
    let digitalReset = GShock(now: { instant }, wallNow: { wall }, restoringStopwatch: digitalPaused.savedStopwatch)
    precondition(!digitalReset.stopwatchRunning && digitalReset.stopwatchElapsed == 0 && digitalReset.split == nil)
    print("Passed: stopwatch JSON checkpoints, original start timestamp, offline/reboot gaps, pause/resume/reset, active clock changes, invalid states, Chronostop hold and G-Shock split/two finishes")
}
