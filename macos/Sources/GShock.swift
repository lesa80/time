import Foundation

struct GShockSettings: Codable, Equatable {
    var use24Hour = true
    var alarmEnabled = false
    var hourlySignal = false
    var alarmHour = 7
    var alarmMinute = 0
    /// Zero means any month/day, as on the 3229 module.
    var alarmMonth = 0
    var alarmDay = 0
    var countdownSeconds = 300
    var autoRepeat = false
    var flashAlert = false

    var isValid: Bool {
        let maximumDay = (1...12).contains(alarmMonth) ? [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][alarmMonth - 1] : 31
        return (0...23).contains(alarmHour) && (0...59).contains(alarmMinute) &&
        (0...12).contains(alarmMonth) && (0...31).contains(alarmDay) &&
        alarmDay <= maximumDay && (1...86_400).contains(countdownSeconds)
    }
}

struct GShockDisplay {
    var fields: [String: String]
    let backlit: Bool
}

/// Active timers use monotonic time, including sleep. Stopwatch checkpoints also
/// restore time between launches. Alarm scheduling uses the local calendar.
/// No redraw, theme switch or wall-clock adjustment changes measured elapsed time.
struct GShock {
    enum Mode: String, CaseIterable {
        case time, alarm, countdown, stopwatch
        var title: String {
            switch self {
            case .time: L("Timekeeping")
            case .alarm: L("Alarm")
            case .countdown: L("Countdown timer")
            case .stopwatch: L("Stopwatch")
            }
        }
    }
    struct StopwatchState: Codable {
        let timer: Chronograph.SavedState
        let split: TimeInterval?
        let wasVisible: Bool
    }
    enum Button { case a, b, c, d }
    enum Alert { case alarm, countdown, hourly }

    private let now: () -> TimeInterval
    var settings: GShockSettings
    private(set) var mode: Mode = .time
    private(set) var editingIndex: Int?
    private var operated = false
    private var lastInteraction: TimeInterval = 0
    private var illuminationUntil: TimeInterval = 0
    private var lastWallDate: Date?
    private var ringingUntil: TimeInterval = 0
    private(set) var alert: Alert?
    private var stopwatch: Chronograph
    private(set) var split: TimeInterval?
    private var countdownStartedAt: TimeInterval?
    private var pausedRemaining: TimeInterval

    init(settings: GShockSettings = GShockSettings(), now: (() -> TimeInterval)? = nil,
         wallNow: @escaping () -> Date = Date.init, restoringStopwatch state: StopwatchState? = nil) {
        let clock: () -> TimeInterval
        if let now { clock = now } else {
            let origin = ContinuousClock.now
            clock = {
                let delta = origin.duration(to: .now).components
                return Double(delta.seconds) + Double(delta.attoseconds) / 1e18
            }
        }
        self.now = clock
        self.settings = settings.isValid ? settings : GShockSettings()
        pausedRemaining = Double(self.settings.countdownSeconds)
        stopwatch = Chronograph(now: clock, wallNow: wallNow, restoring: state?.timer)
        if let state, state.timer.isValid {
            if let split = state.split, split.isFinite, split >= 0, split <= state.timer.elapsed { self.split = split }
            if state.wasVisible { mode = .stopwatch }
        }
    }

    var savedStopwatch: StopwatchState {
        StopwatchState(timer: stopwatch.savedState, split: split, wasVisible: mode == .stopwatch)
    }
    var isEditing: Bool { editingIndex != nil }
    var stopwatchRunning: Bool { stopwatch.isRunning }
    var stopwatchElapsed: TimeInterval { stopwatch.reading.elapsed }
    var countdownRunning: Bool { countdownStartedAt != nil }
    var remaining: TimeInterval {
        max(0, pausedRemaining - (countdownStartedAt.map { max(0, now() - $0) } ?? 0))
    }
    var isRinging: Bool { alert != nil && now() < ringingUntil }
    var needsService: Bool { settings.alarmEnabled || settings.hourlySignal || countdownRunning || alert != nil }
    var needsFastRefresh: Bool { (mode == .stopwatch && stopwatchRunning && split == nil) || isEditing }

    mutating func resynchronizeWallClock(date: Date) { lastWallDate = date }
    mutating func selectMode(_ selected: Mode) {
        mode = selected
        editingIndex = nil
        operated = false
    }
    mutating func configure(_ selected: GShockSettings) {
        guard selected.isValid else { return }
        let durationChanged = selected.countdownSeconds != settings.countdownSeconds
        if (!selected.alarmEnabled && alert == .alarm) || (!selected.hourlySignal && alert == .hourly) ||
            (durationChanged && alert == .countdown) { silence() }
        settings = selected
        if durationChanged { resetCountdown() }
        editingIndex = nil
    }
    mutating func silence() {
        alert = nil
        ringingUntil = 0
        if !countdownRunning && pausedRemaining == 0 { pausedRemaining = Double(settings.countdownSeconds) }
    }
    mutating func resetCountdown() {
        countdownStartedAt = nil
        pausedRemaining = Double(settings.countdownSeconds)
    }

    /// Returns only newly triggered events. Long wake gaps produce one event, never a burst of alarms.
    @discardableResult
    mutating func tick(date: Date, calendar: Calendar = .current) -> Alert? {
        let instant = now()
        if alert != nil && !isRinging { silence() }
        if isEditing && instant - lastInteraction >= 120 { editingIndex = nil }
        var triggered: Alert?
        if let started = countdownStartedAt, remaining <= 0 {
            if settings.autoRepeat {
                let duration = Double(settings.countdownSeconds)
                let elapsed = max(0, instant - started)
                // pausedRemaining can be less than a complete cycle after a pause/resume.
                let overshoot = max(0, elapsed - pausedRemaining)
                countdownStartedAt = instant - overshoot.truncatingRemainder(dividingBy: duration)
                pausedRemaining = duration
            } else {
                countdownStartedAt = nil
                pausedRemaining = 0
            }
            triggered = .countdown
        }
        if let previous = lastWallDate, date >= previous,
           floor(date.timeIntervalSinceReferenceDate) != floor(previous.timeIntervalSinceReferenceDate) {
            if settings.hourlySignal, let boundary = calendar.dateInterval(of: .hour, for: date)?.start,
               boundary > previous, date.timeIntervalSince(boundary) < 2 { triggered = triggered ?? .hourly }
            if settings.alarmEnabled {
                var match = DateComponents()
                match.hour = settings.alarmHour; match.minute = settings.alarmMinute; match.second = 0
                if settings.alarmMonth != 0 { match.month = settings.alarmMonth }
                if settings.alarmDay != 0 { match.day = settings.alarmDay }
                if let due = calendar.nextDate(after: previous, matching: match, matchingPolicy: .strict,
                                               repeatedTimePolicy: .first), due <= date { triggered = .alarm }
            }
        }
        lastWallDate = date
        if let triggered {
            alert = triggered
            ringingUntil = instant + (triggered == .alarm ? 20 : triggered == .countdown ? 10 : 0.3)
            illuminationUntil = 0
        }
        return triggered
    }

    mutating func press(_ button: Button, long: Bool = false) {
        if isRinging { silence(); return }
        lastInteraction = now()
        if long {
            if button == .b && mode == .time && !isEditing { settings.flashAlert.toggle() }
            return
        }
        if button == .c {
            if let index = editingIndex {
                editingIndex = (index + 1) % (mode == .alarm ? 4 : mode == .countdown ? 3 : 1)
            } else if operated {
                selectMode(.time)
            } else {
                let modes = Mode.allCases
                selectMode(modes[(modes.firstIndex(of: mode)! + 1) % modes.count])
            }
            return
        }
        if button == .d {
            if isEditing && mode == .time { settings.use24Hour.toggle() }
            else if isEditing && mode == .countdown { settings.autoRepeat.toggle() }
            else { illuminationUntil = now() + 2 }
            return
        }
        switch mode {
        case .time:
            // Desktop time remains synchronized with macOS; Adjust selects only 12/24-hour format.
            if button == .a { editingIndex = isEditing ? nil : 0 }
        case .alarm:
            if button == .a {
                editingIndex = isEditing ? nil : 0
                if isEditing { settings.alarmEnabled = true }
            } else if button == .b {
                if let index = editingIndex {
                    switch index {
                    case 0: settings.alarmHour = (settings.alarmHour + 1) % 24
                    case 1: settings.alarmMinute = (settings.alarmMinute + 1) % 60
                    case 2: settings.alarmMonth = (settings.alarmMonth + 1) % 13
                    default: settings.alarmDay = (settings.alarmDay + 1) % 32
                    }
                } else {
                    let flags = (settings.alarmEnabled ? 1 : 0) + (settings.hourlySignal ? 2 : 0)
                    let sequence = [0, 1, 3, 2]
                    let next = sequence[(sequence.firstIndex(of: flags)! + 1) % sequence.count]
                    settings.alarmEnabled = next & 1 != 0
                    settings.hourlySignal = next & 2 != 0
                }
                operated = true
            }
        case .countdown:
            if isEditing {
                if button == .a { editingIndex = nil }
                else if button == .b {
                    let seconds = settings.countdownSeconds == 86_400 ? 0 : settings.countdownSeconds
                    var h = seconds / 3600, m = seconds / 60 % 60, s = seconds % 60
                    switch editingIndex! {
                    case 0: h = (h + 1) % 24
                    case 1: m = (m + 1) % 60
                    default: s = (s + 1) % 60
                    }
                    let total = h * 3600 + m * 60 + s
                    settings.countdownSeconds = total == 0 ? 86_400 : total
                    resetCountdown()
                }
            } else if button == .b {
                if countdownRunning {
                    pausedRemaining = remaining
                    countdownStartedAt = nil
                } else { countdownStartedAt = now() }
                operated = true
            } else if button == .a && !countdownRunning {
                if abs(pausedRemaining - Double(settings.countdownSeconds)) > 0.001 { resetCountdown() }
                else { editingIndex = 0 }
                operated = true
            }
        case .stopwatch:
            if button == .b {
                if stopwatch.isRunning { stopwatch.pause() } else { stopwatch.start() }
            } else if button == .a {
                if stopwatch.isRunning { split = split == nil ? stopwatch.reading.elapsed : nil }
                else if split != nil { split = nil }
                else { stopwatch.reset() }
            }
            operated = true
        }
    }

    func display(date: Date, calendar: Calendar = .current, reduceMotion: Bool = false) -> GShockDisplay {
        let time = HandAngles(date: date, calendar: calendar)
        func two(_ n: Int) -> String { String(format: "%02ld", n) }
        func hour(_ h: Int) -> String { two(settings.use24Hour ? h : (h % 12 == 0 ? 12 : h % 12)) }
        var fields = ["weekday": time.text(for: "weekday"), "month": two(time.month), "day": two(time.day),
                      "hours": hour(time.hours), "minutes": two(time.minutes), "seconds": two(time.seconds),
                      "format": settings.use24Hour ? "24H" : time.hours >= 12 ? "PM " : "   ",
                      "indicators": "\(settings.alarmEnabled ? "AL" : "  ") \(settings.hourlySignal ? "SIG" : "   ") \(settings.autoRepeat ? "R" : " ") \(settings.flashAlert ? "F" : " ") \(split != nil ? "SP" : "  ")",
                      "separator": "-"]
        switch mode {
        case .time: break
        case .alarm:
            fields["weekday"] = "AL"
            fields["month"] = settings.alarmMonth == 0 ? "--" : two(settings.alarmMonth)
            fields["day"] = settings.alarmDay == 0 ? "--" : two(settings.alarmDay)
            fields["hours"] = hour(settings.alarmHour)
            fields["minutes"] = two(settings.alarmMinute)
            fields["seconds"] = "  "
            fields["format"] = settings.use24Hour ? "24H" : settings.alarmHour >= 12 ? "PM " : "   "
        case .countdown, .stopwatch:
            fields["weekday"] = mode == .countdown ? "TR" : "ST"
            fields["month"] = hour(time.hours)
            fields["day"] = two(time.minutes)
            fields["separator"] = ":"
            if mode == .stopwatch {
                // Do not lose a completed centisecond to floating-point subtraction at its boundary.
                let elapsed = ((split ?? stopwatch.reading.elapsed) + 1e-7).truncatingRemainder(dividingBy: 86_400)
                let seconds = Int(elapsed)
                fields["hours"] = two(elapsed < 3600 ? seconds / 60 : seconds / 3600)
                fields["minutes"] = two(elapsed < 3600 ? seconds % 60 : seconds / 60 % 60)
                fields["seconds"] = two(elapsed < 3600 ? Int((elapsed * 100).rounded(.down)) % 100 : seconds % 60)
            } else {
                let seconds = isEditing && settings.countdownSeconds == 86_400 ? 0 : Int(remaining.rounded(.up))
                fields["hours"] = two(seconds / 3600)
                fields["minutes"] = two(seconds / 60 % 60)
                fields["seconds"] = two(seconds % 60)
            }
        }
        if let index = editingIndex, !reduceMotion && Int(now() * 2) % 2 == 0 {
            let field: String
            switch mode {
            case .time: field = "format"
            case .alarm: field = ["hours", "minutes", "month", "day"][index]
            case .countdown: field = ["hours", "minutes", "seconds"][index]
            case .stopwatch: field = "weekday"
            }
            fields[field] = String(repeating: " ", count: fields[field]!.count)
        }
        let flashing = isRinging && settings.flashAlert && (reduceMotion || Int(now() * 4) % 2 == 0)
        return GShockDisplay(fields: fields, backlit: now() < illuminationUntil || flashing)
    }
}
