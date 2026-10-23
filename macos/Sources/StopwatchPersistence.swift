import Foundation

/// One preferences value keeps stopwatch and countdown checkpoints consistent. Nothing
/// is written on animation frames; checkpoints are made on actions/lifecycle events.
struct SavedStopwatches: Codable {
    var version = 1
    let analog: Chronograph.SavedState
    let chronostop: Chronograph.SavedState
    let gshock: GShock.StopwatchState
    var countdown: GShock.CountdownState? = nil
}

@MainActor
extension AppDelegate {
    func saveStopwatches() {
        let state = SavedStopwatches(analog: chronograph.savedState, chronostop: chronostop.savedState,
                                    gshock: gshock.savedStopwatch, countdown: gshock.savedCountdown)
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: "stopwatchState") }
    }
}
