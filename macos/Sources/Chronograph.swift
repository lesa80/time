import Foundation

/// Continuous time measures the active process, including sleep. A wall-clock
/// checkpoint restores the interval while the app was closed or the Mac rebooted.
struct Chronograph {
    struct SavedState: Codable {
        var version = 1
        let elapsed: TimeInterval
        let savedAt: Date
        let startDate: Date?
        let isRunning: Bool

        var isValid: Bool {
            version == 1 && elapsed.isFinite && elapsed >= 0 &&
                savedAt.timeIntervalSinceReferenceDate.isFinite &&
                (startDate?.timeIntervalSinceReferenceDate.isFinite ?? true) &&
                (startDate != nil || (!isRunning && elapsed == 0))
        }
    }

    private let now: () -> TimeInterval
    private let wallNow: () -> Date
    private var accumulated: TimeInterval = 0
    private var startedAt: TimeInterval?
    private(set) var startDate: Date?

    init(now: (() -> TimeInterval)? = nil, wallNow: @escaping () -> Date = Date.init,
         restoring state: SavedState? = nil) {
        self.wallNow = wallNow
        if let now { self.now = now } else {
            let origin = ContinuousClock.now
            self.now = {
                let duration = origin.duration(to: .now).components
                return Double(duration.seconds) + Double(duration.attoseconds) / 1e18
            }
        }
        if let state, state.isValid {
            let gap = state.isRunning ? max(0, wallNow().timeIntervalSince(state.savedAt)) : 0
            let restored = state.elapsed + gap
            guard restored.isFinite else { return }
            accumulated = restored
            startDate = state.startDate
            if state.isRunning { startedAt = self.now() }
        }
    }

    var isRunning: Bool { startedAt != nil }
    var reading: ChronographReading {
        ChronographReading(elapsed: accumulated + (startedAt.map { max(0, now() - $0) } ?? 0))
    }
    var savedState: SavedState {
        SavedState(elapsed: reading.elapsed, savedAt: wallNow(), startDate: startDate, isRunning: isRunning)
    }
    mutating func start() {
        guard !isRunning else { return }
        if startDate == nil { startDate = wallNow() }
        startedAt = now()
    }
    mutating func pause() {
        guard isRunning else { return }
        accumulated = reading.elapsed
        startedAt = nil
    }
    mutating func reset() {
        accumulated = 0
        startedAt = nil
        startDate = nil
    }
}

struct ChronographReading {
    let elapsed: TimeInterval
    init(elapsed: TimeInterval = 0) {
        self.elapsed = elapsed.isFinite ? max(0, elapsed) : 0
    }
    func angle(for image: String) -> Double {
        let period: Double
        switch URL(fileURLWithPath: image).deletingPathExtension().lastPathComponent {
        case "chrono-second": period = 60
        case "chrono-minute": period = 30 * 60
        case "chrono-hour": period = 12 * 60 * 60
        default: return 0
        }
        return elapsed.truncatingRemainder(dividingBy: period) / period * 360
    }
    var text: String {
        let seconds = Int(min(elapsed, Double(Int.max / 2)))
        return String(format: "%02ld:%02ld:%02ld", seconds / 3600, seconds / 60 % 60, seconds % 60)
    }
}
