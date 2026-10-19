import Foundation

func checkPulsarModel() {
    var now: TimeInterval = 0
    var pulsar = Pulsar(now: { now })
    precondition(!pulsar.reading.isLit)
    pulsar.illuminate()
    precondition(pulsar.reading.mode == .time)
    now += 1.249
    precondition(pulsar.reading.mode == .time)
    now += 0.002
    precondition(!pulsar.reading.isLit)
    pulsar.press(); now += 0.2; pulsar.release()
    precondition(pulsar.reading.mode == .time)
    now += 1.1
    precondition(!pulsar.reading.isLit)
    pulsar.press(); now += 1.251
    precondition(pulsar.reading.mode == .seconds)
    now += 45
    precondition(pulsar.reading.mode == .seconds)
    pulsar.release()
    precondition(!pulsar.reading.isLit)
    pulsar.illuminate(seconds: true)
    precondition(pulsar.reading.mode == .seconds)
    pulsar.cancel()
    precondition(!pulsar.reading.isLit)
    pulsar.press(); pulsar.cancel(); now += 2; pulsar.release()
    precondition(!pulsar.reading.isLit)
    let midnight = HandAngles(hours: 0, minutes: 4, seconds: 8)
    let afternoon = HandAngles(hours: 13, minutes: 45, seconds: 58)
    precondition(midnight.text(for: "hours12") == "12" && afternoon.text(for: "hours12") == " 1")
    precondition(afternoon.text(for: "colon") == ":")
    print("Passed: Pulsar timeout/hold/release/cancel and 12-hour LED fields")
}
