import Foundation

/// Elapsed time is independent of the wall clock, timezone and redraw timer.
/// ContinuousClock also includes time spent asleep. State lasts for this app session.
struct Chronograph {
    private let now: () -> TimeInterval
    private var accumulated: TimeInterval = 0
    private var startedAt: TimeInterval?

    init(now: (() -> TimeInterval)? = nil) {
        if let now { self.now = now } else {
            let origin = ContinuousClock.now
            self.now = {
                let duration = origin.duration(to: .now).components
                return Double(duration.seconds) + Double(duration.attoseconds) / 1e18
            }
        }
    }

    var isRunning: Bool { startedAt != nil }
    var reading: ChronographReading {
        ChronographReading(elapsed: accumulated + (startedAt.map { max(0, now() - $0) } ?? 0))
    }
    mutating func start() {
        guard !isRunning else { return }
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
