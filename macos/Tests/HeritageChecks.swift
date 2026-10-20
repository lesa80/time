import Foundation

func checkHeritageModels() throws {
    var now: TimeInterval = 100
    var stop = Chronostop(now: { now })
    stop.press(); now += 0.2; stop.release()
    precondition(stop.isRunning && !stop.readingHeld, "Initial release must keep the timer running")
    now += 62.3
    precondition(abs(stop.reading.angle(for: "chrono-second.png") - 15) < 0.001, "One full revolution is 60 seconds")
    stop.press(); let held = stop.reading.elapsed; now += 5
    precondition(!stop.isRunning && stop.readingHeld && stop.reading.elapsed == held)
    stop.release()
    precondition(stop.reading.elapsed == 0 && !stop.readingHeld)
    stop.start(); now += 2; stop.read()
    precondition(stop.readingHeld && stop.reading.elapsed == 2)
    stop.reset(); precondition(stop.reading.elapsed == 0)

    let date = Date(timeIntervalSince1970: 1_800_000_000)
    var parking = ParkingAlarm()
    parking.set(minutes: 30, date: date)
    precondition(parking.isArmed && !parking.isRinging)
    let deadline = date.addingTimeInterval(1800)
    precondition(parking.settings.deadline == deadline)
    precondition(abs(parking.settings.angle - ParkingAlarm.angle(at: deadline)) < 0.001)
    let restored = ParkingAlarm(settings: try JSONDecoder().decode(ParkingSettings.self, from: JSONEncoder().encode(parking.settings)))
    precondition(restored.settings.deadline == deadline && restored.settings.angle == parking.settings.angle)
    precondition(!parking.tick(date: deadline.addingTimeInterval(-0.001)))
    precondition(parking.tick(date: deadline) && parking.isRinging && !parking.isArmed)
    precondition(!parking.tick(date: deadline.addingTimeInterval(1)))
    parking.tick(date: deadline.addingTimeInterval(21)); precondition(!parking.needsService)
    parking.set(minutes: 15, date: date)
    precondition(parking.tick(date: date.addingTimeInterval(10_000)), "A missed alarm fires once after wake")
    parking.cancel(); precondition(!parking.isArmed && !parking.isRinging)
    parking.rotate(by: 375, date: date); precondition(abs(parking.settings.angle - ParkingAlarm.normalized(ParkingAlarm.angle(at: date.addingTimeInterval(900)) + 15)) < 0.001)
    parking.arm(date: date)
    let firstDeadline = parking.settings.deadline!
    parking.rotate(by: 1, date: date)
    precondition(abs(parking.settings.deadline!.timeIntervalSince(firstDeadline) - 120) < 0.001)
    precondition(ParkingAlarm.normalized(-1) == 359 && ParkingAlarm.normalized(.nan) == 0)
    let previous = parking.settings.angle
    parking.rotate(by: .infinity, date: date); precondition(parking.settings.angle == previous)
    print("Passed: Chronostop initial release/read/hold/reset/rollover, Parking disc/deadline/persistence/wake/single alarm/cancel")
}
