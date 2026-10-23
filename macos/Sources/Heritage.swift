import Foundation

/// One-button 60-second chronograph: press to start, press/hold to read,
/// release the reading press to reset. The initial press never resets on release.
struct Chronostop {
    private var timer: Chronograph
    private(set) var readingHeld = false
    init(now: (() -> TimeInterval)? = nil, wallNow: @escaping () -> Date = Date.init,
         restoring state: Chronograph.SavedState? = nil) {
        timer = Chronograph(now: now, wallNow: wallNow, restoring: state)
        readingHeld = !timer.isRunning && timer.startDate != nil
    }
    var savedState: Chronograph.SavedState { timer.savedState }
    var isRunning: Bool { timer.isRunning }
    var reading: ChronographReading { timer.reading }
    mutating func press() {
        if timer.isRunning { timer.pause(); readingHeld = true }
        else if readingHeld { reset() }
        else { timer.start() }
    }
    mutating func release() { if readingHeld { reset() } }
    mutating func reset() { timer.reset(); readingHeld = false }
    mutating func read() { if timer.isRunning { timer.pause(); readingHeld = true } }
    mutating func start() { if readingHeld { reset() }; timer.start() }
}

struct ParkingSettings: Codable {
    var angle: Double = 0
    var deadline: Date?
    var isValid: Bool { angle.isFinite && (deadline?.timeIntervalSince1970.isFinite ?? true) }
}

/// A single alarm on a 12-hour dial; its pointer and deadline always agree.
/// A due alarm rings once, including after sleep, and never repeats every 12 hours.
struct ParkingAlarm {
    private(set) var settings: ParkingSettings
    private(set) var ringUntil: Date?
    init(settings: ParkingSettings = ParkingSettings()) {
        self.settings = settings.isValid ? settings : ParkingSettings()
        self.settings.angle = Self.normalized(self.settings.angle)
    }
    var isArmed: Bool { settings.deadline != nil }
    var isRinging: Bool { ringUntil != nil }
    var needsService: Bool { isArmed || isRinging }
    static func normalized(_ angle: Double) -> Double {
        guard angle.isFinite else { return 0 }
        return (angle.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }
    static func angle(at date: Date, calendar: Calendar = .autoupdatingCurrent) -> Double {
        let c = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        return Double(c.hour! % 12) * 30 + Double(c.minute!) / 2 + Double(c.second!) / 120 + Double(c.nanosecond!) / 120e9
    }
    mutating func rotate(by delta: Double, date: Date) {
        guard delta.isFinite else { return }
        settings.angle = Self.normalized(settings.angle + delta)
        if isArmed { arm(date: date) }
    }
    mutating func arm(date: Date) {
        let delta = Self.normalized(settings.angle - Self.angle(at: date))
        settings.deadline = date.addingTimeInterval((delta < 0.0001 ? 360 : delta) * 120)
        ringUntil = nil
    }
    mutating func set(minutes: Int, date: Date) {
        guard (1...720).contains(minutes) else { return }
        let deadline = date.addingTimeInterval(Double(minutes) * 60)
        settings.angle = Self.angle(at: deadline)
        settings.deadline = deadline
        ringUntil = nil
    }
    mutating func cancel() { settings.deadline = nil; ringUntil = nil }
    @discardableResult mutating func tick(date: Date) -> Bool {
        if let deadline = settings.deadline, date >= deadline {
            settings.deadline = nil
            ringUntil = date.addingTimeInterval(20)
            return true
        }
        if let until = ringUntil, date >= until { ringUntil = nil }
        return false
    }
}

struct HeritageReading {
    var parkingAngle: Double = 0
    var slideRuleAngle: Double = 0
    var chronostop = ChronographReading()
}
