import Foundation

/// One preferences value keeps the three stopwatch mechanisms consistent. Nothing
/// is written on animation frames; checkpoints are made on actions/lifecycle events.
struct SavedStopwatches: Codable {
    var version = 1
    let analog: Chronograph.SavedState
    let chronostop: Chronograph.SavedState
    let gshock: GShock.StopwatchState
}

@MainActor
extension AppDelegate {
    func saveStopwatches() {
        let state = SavedStopwatches(analog: chronograph.savedState, chronostop: chronostop.savedState, gshock: gshock.savedStopwatch)
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: "stopwatchState") }
    }
}
