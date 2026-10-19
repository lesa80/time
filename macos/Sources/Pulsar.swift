import Foundation

struct PulsarReading {
    enum Mode { case off, time, seconds }
    var mode: Mode = .off
    var isLit: Bool { mode != .off }
}

/// Uses monotonic elapsed time; displayed digits always come from the Mac's local clock.
struct Pulsar {
    static let displayDuration: TimeInterval = 1.25
    private let now: () -> TimeInterval
    private var pressedAt: TimeInterval?
    private var expiresAt: TimeInterval?
    private var timedMode: PulsarReading.Mode = .time

    init(now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) { self.now = now }
    var reading: PulsarReading {
        if let pressedAt {
            return PulsarReading(mode: now() - pressedAt >= Self.displayDuration ? .seconds : .time)
        }
        return PulsarReading(mode: expiresAt.map { now() < $0 } == true ? timedMode : .off)
    }
    mutating func press() { pressedAt = now(); expiresAt = nil }
    mutating func release() {
        guard let began = pressedAt else { return }
        pressedAt = nil
        timedMode = .time
        expiresAt = now() < began + Self.displayDuration ? began + Self.displayDuration : nil
    }
    mutating func illuminate(seconds: Bool = false) {
        pressedAt = nil
        timedMode = seconds ? .seconds : .time
        expiresAt = now() + Self.displayDuration
    }
    mutating func cancel() { pressedAt = nil; expiresAt = nil }
}
