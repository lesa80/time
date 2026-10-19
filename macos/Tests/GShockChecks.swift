import Foundation

private func checkGShockCondition(_ condition: @autoclosure () -> Bool, _ message: String = "", line: UInt = #line) {
    if !condition() {
        FileHandle.standardError.write(Data("G-Shock test failed at line \(line): \(message)\n".utf8))
        exit(1)
    }
}

func checkGShock() throws {
    var now: TimeInterval = 0
    var watch = GShock(now: { now })
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(secondsFromGMT: 0)!
    let start = ISO8601DateFormatter().date(from: "2026-10-19T06:59:59Z")!
    func display(_ date: Date = start) -> [String: String] { watch.display(date: date, calendar: utc, reduceMotion: true).fields }
    for mode in GShock.Mode.allCases {
        checkGShockCondition(watch.mode == mode)
        watch.press(.c)
    }
    checkGShockCondition(watch.mode == .time)
    watch.press(.a); watch.press(.d); watch.press(.a)
    checkGShockCondition(!watch.settings.use24Hour && !watch.isEditing)
    checkGShockCondition(display(start.addingTimeInterval(6 * 3600 + 1))["format"] == "PM ")
    let midnight = ISO8601DateFormatter().date(from: "2026-10-20T00:00:00Z")!
    checkGShockCondition(display(midnight)["hours"] == "12" && display(midnight)["format"] == "   ")
    watch.press(.b)
    checkGShockCondition(!watch.settings.flashAlert)
    watch.press(.b, long: true)
    checkGShockCondition(watch.settings.flashAlert)
    watch.press(.d)
    checkGShockCondition(watch.display(date: start).backlit)
    now += 2.01
    checkGShockCondition(!watch.display(date: start).backlit)
    watch.press(.a)
    now += 120
    watch.tick(date: start)
    checkGShockCondition(!watch.isEditing)

    watch.selectMode(.stopwatch)
    watch.press(.b)
    now += 12.34
    close(watch.stopwatchElapsed, 12.34, "G-Shock monotonic stopwatch")
    checkGShockCondition(display()["hours"] == "00" && display()["minutes"] == "12" && display()["seconds"] == "34")
    watch.press(.a)
    let split = watch.split!
    now += 7
    close(watch.split!, split, "Split freezes only the displayed value")
    watch.press(.b)
    let finish = watch.stopwatchElapsed
    now += 10
    close(watch.stopwatchElapsed, finish, "Second finisher stops the stopwatch internally")
    watch.press(.a)
    checkGShockCondition(watch.split == nil)
    close(watch.stopwatchElapsed, finish, "Releasing split shows the second finishing time")
    watch.press(.a)
    close(watch.stopwatchElapsed, 0, "Stopped stopwatch reset")
    watch.press(.b)
    watch.selectMode(.alarm)
    now += 3661
    watch.selectMode(.stopwatch)
    checkGShockCondition(display()["hours"] == "01" && display()["minutes"] == "01" && display()["seconds"] == "01")
    now += 86_400
    checkGShockCondition(display()["hours"] == "01", "Stopwatch wraps at 24 hours while continuing to count")
    watch.press(.c)
    // Direct mode selection clears the original mode-return flag; a new stopwatch operation sets it.
    watch.selectMode(.stopwatch); watch.press(.b); watch.press(.c)
    checkGShockCondition(watch.mode == .time)

    var settings = GShockSettings()
    settings.countdownSeconds = 10
    watch.configure(settings)
    watch.selectMode(.countdown)
    watch.press(.b)
    now += 3.25
    close(watch.remaining, 6.75, "Countdown fractional elapsed time")
    watch.press(.b)
    now += 5000
    close(watch.remaining, 6.75, "Paused countdown must not advance")
    watch.press(.b)
    now += 7
    checkGShockCondition(watch.tick(date: start) == .countdown && watch.isRinging && !watch.countdownRunning)
    checkGShockCondition(watch.tick(date: start) == nil, "A finished countdown must not repeatedly create alarms")
    let previousMode = watch.mode
    watch.press(.c)
    checkGShockCondition(!watch.isRinging && watch.mode == previousMode, "Any pusher silences before performing its normal action")
    close(watch.remaining, 10, "Silencing a completed countdown restores its starting value")

    settings.autoRepeat = true
    watch.configure(settings)
    watch.selectMode(.countdown)
    watch.press(.b)
    now += 26
    checkGShockCondition(watch.tick(date: start) == .countdown && watch.countdownRunning)
    close(watch.remaining, 4, "Repeated countdown retains phase after multiple missed cycles")
    watch.silence()
    watch.press(.b)
    now += 100
    watch.press(.b)
    now += 7
    watch.tick(date: start)
    close(watch.remaining, 7, "Auto repeat retains phase after pause and resume")
    watch.silence()
    watch.press(.b); watch.press(.a)
    close(watch.remaining, 10, "Paused timer reset")
    watch.press(.a); watch.press(.d)
    checkGShockCondition(watch.isEditing && !watch.settings.autoRepeat)
    watch.press(.c); watch.press(.b)
    checkGShockCondition(watch.settings.countdownSeconds == 70, "Timer editor increments the selected minute field")
    watch.press(.a)
    checkGShockCondition(!watch.isEditing)

    watch = GShock(now: { now })
    watch.selectMode(.alarm)
    for expected in [(true, false), (true, true), (false, true), (false, false)] {
        watch.press(.b)
        checkGShockCondition(watch.settings.alarmEnabled == expected.0 && watch.settings.hourlySignal == expected.1)
    }
    watch.press(.a); watch.press(.b); watch.press(.c); watch.press(.b)
    watch.press(.c); watch.press(.b); watch.press(.c); watch.press(.b); watch.press(.a)
    checkGShockCondition(watch.settings.alarmHour == 8 && watch.settings.alarmMinute == 1 &&
                 watch.settings.alarmMonth == 1 && watch.settings.alarmDay == 1 && watch.settings.alarmEnabled)
    let encoded = try JSONEncoder().encode(watch.settings)
    let decoded = try JSONDecoder().decode(GShockSettings.self, from: encoded)
    checkGShockCondition(decoded == watch.settings)
    settings = GShockSettings()
    settings.alarmMonth = 2; settings.alarmDay = 30
    checkGShockCondition(!settings.isValid)
    settings.alarmDay = 29
    checkGShockCondition(settings.isValid)
    settings.countdownSeconds = 86_401
    checkGShockCondition(!settings.isValid && GShock(settings: settings).settings == GShockSettings())

    settings = GShockSettings()
    settings.alarmEnabled = true; settings.hourlySignal = true; settings.flashAlert = true
    watch = GShock(settings: settings, now: { now })
    watch.resynchronizeWallClock(date: start)
    checkGShockCondition(watch.tick(date: start.addingTimeInterval(1), calendar: utc) == .alarm)
    checkGShockCondition(watch.isRinging && watch.display(date: start, reduceMotion: true).backlit)
    checkGShockCondition(watch.tick(date: start.addingTimeInterval(1.1), calendar: utc) == nil)
    now += 21
    watch.tick(date: start.addingTimeInterval(22), calendar: utc)
    checkGShockCondition(!watch.isRinging)
    checkGShockCondition(watch.tick(date: start.addingTimeInterval(3601), calendar: utc) == .hourly)
    watch.silence()
    // Sleeping skips redraws; due alarms are delivered once on wake, not by scheduling repeated beeps for missed hours.
    watch.resynchronizeWallClock(date: start)
    checkGShockCondition(watch.tick(date: start.addingTimeInterval(7201), calendar: utc) == .alarm)
    watch.silence()
    checkGShockCondition(watch.tick(date: start.addingTimeInterval(7202), calendar: utc) == nil)
    watch.resynchronizeWallClock(date: start.addingTimeInterval(7203))
    checkGShockCondition(watch.tick(date: start.addingTimeInterval(7204), calendar: utc) == nil)

    settings.hourlySignal = false; settings.alarmMonth = 2; settings.alarmDay = 29
    watch = GShock(settings: settings, now: { now })
    let leap = ISO8601DateFormatter().date(from: "2028-02-29T06:59:59Z")!
    watch.resynchronizeWallClock(date: leap)
    checkGShockCondition(watch.tick(date: leap.addingTimeInterval(1), calendar: utc) == .alarm)
    watch.silence()
    let nextDay = ISO8601DateFormatter().date(from: "2028-03-01T06:59:59Z")!
    watch.resynchronizeWallClock(date: nextDay)
    checkGShockCondition(watch.tick(date: nextDay.addingTimeInterval(1), calendar: utc) == nil)
    var ny = utc
    ny.timeZone = TimeZone(identifier: "America/New_York")!
    settings.alarmMonth = 0; settings.alarmDay = 0; settings.alarmHour = 1; settings.alarmMinute = 30
    watch = GShock(settings: settings, now: { now })
    let fall = ISO8601DateFormatter().date(from: "2026-11-01T05:29:59Z")!
    watch.resynchronizeWallClock(date: fall)
    checkGShockCondition(watch.tick(date: fall.addingTimeInterval(1), calendar: ny) == .alarm)
    watch.silence()
    checkGShockCondition(watch.tick(date: fall.addingTimeInterval(3601), calendar: ny) == nil,
                 "Repeated local DST hour must not sound the daily alarm twice")
    watch.resynchronizeWallClock(date: start)
    settings = GShockSettings(); settings.alarmEnabled = true
    watch.configure(settings)
    watch.tick(date: start.addingTimeInterval(1), calendar: utc)
    checkGShockCondition(watch.isRinging)
    settings.alarmEnabled = false
    watch.configure(settings)
    checkGShockCondition(!watch.isRinging, "Disabling an alarm must also silence an active alarm")
    print("Passed: G-Shock modes, 12/24h, light, flash, split/two finishes, 24h rollover, countdown pause/repeat/sleep, alarm calendar/DST and saved settings")
}
