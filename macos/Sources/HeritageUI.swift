import AppKit

@MainActor
extension AppDelegate {
    func addHeritageMenuItems(to menu: NSMenu) {
        add("stopStep", L("Start 60-second timer"), #selector(chronostopMenuAction), to: menu)
        add("stopReset", L("Reset chronograph"), #selector(resetChronostop), to: menu)
        let reading = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        reading.isEnabled = false; menu.addItem(reading); menuActions["stopReading"] = reading
        let durations = NSMenu(title: L("Parking reminder")); durations.autoenablesItems = false
        for minutes in [15, 30, 60, 120] {
            let item = NSMenuItem(title: L("%ld min", minutes), action: #selector(setParkingDuration(_:)), keyEquivalent: "")
            item.tag = minutes; item.target = self; durations.addItem(item)
        }
        let parkingItem = NSMenuItem(title: L("Parking reminder"), action: nil, keyEquivalent: "")
        parkingItem.submenu = durations; menu.addItem(parkingItem); menuActions["parkingDuration"] = parkingItem
        add("parkingEnabled", L("Alarm enabled"), #selector(toggleParkingAlarm), to: menu)
        add("parkingStop", L("Stop alarm sound"), #selector(cancelParking), to: menu)
        let status = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        status.isEnabled = false; menu.addItem(status); menuActions["parkingStatus"] = status
        add("slideLeft", L("Rotate scale −1°"), #selector(rotateScaleLeft), to: menu)
        add("slideRight", L("Rotate scale +1°"), #selector(rotateScaleRight), to: menu)
        add("slideReset", L("Reset slide rule"), #selector(resetSlideRule), to: menu)
    }
    func updateHeritageMenu() {
        for key in ["stopStep", "stopReset", "stopReading"] { menuActions[key]?.isHidden = !renderer.isChronostop }
        menuActions["stopStep"]?.title = chronostop.isRunning ? L("Hold reading") : chronostop.readingHeld ? L("Reset chronograph") : L("Start 60-second timer")
        menuActions["stopReset"]?.isEnabled = chronostop.isRunning || chronostop.readingHeld
        menuActions["stopReading"]?.title = String(format: "%.1f s", chronostop.reading.elapsed.truncatingRemainder(dividingBy: 60))
        for key in ["parkingDuration", "parkingEnabled", "parkingStatus"] { menuActions[key]?.isHidden = !renderer.isParking }
        menuActions["parkingEnabled"]?.state = parking.isArmed ? .on : .off
        menuActions["parkingStop"]?.isHidden = !parking.isRinging
        if let deadline = parking.settings.deadline {
            menuActions["parkingStatus"]?.title = L("Alarm: %@", DateFormatter.localizedString(from: deadline, dateStyle: .none, timeStyle: .short))
        } else { menuActions["parkingStatus"]?.title = parking.isRinging ? L("Alarm") : L("Disabled") }
        for key in ["slideLeft", "slideRight", "slideReset"] { menuActions[key]?.isHidden = !renderer.isNavitimer }
    }
    func finishHeritageInteraction() {
        lastAccessibilitySecond = -1
        updateChronographMenu(); refreshGShockService()
        if clockView != nil && window != nil { startTimer() }
    }
    @objc func chronostopMenuAction() {
        guard renderer.isChronostop else { return }
        if chronostop.isRunning { chronostop.read() }
        else if chronostop.readingHeld { chronostop.reset() }
        else { chronostop.start() }
        finishHeritageInteraction()
    }
    @objc func resetChronostop() { guard renderer.isChronostop else { return }; chronostop.reset(); finishHeritageInteraction() }
    @objc func setParkingDuration(_ item: NSMenuItem) {
        guard renderer.isParking else { return }
        parking.set(minutes: item.tag, date: Date()); saveParking(); finishHeritageInteraction()
    }
    @objc func toggleParkingAlarm() {
        guard renderer.isParking else { return }
        if parking.isArmed || parking.isRinging { parking.cancel() } else { parking.arm(date: Date()) }
        saveParking(); finishHeritageInteraction()
    }
    @objc func cancelParking() {
        parking.cancel(); NSSound(named: NSSound.Name("Ping"))?.stop(); saveParking(); finishHeritageInteraction()
    }
    func saveParking() {
        if let data = try? JSONEncoder().encode(parking.settings) { defaults.set(data, forKey: "parkingSettings") }
    }
    func advanceParking(date: Date) {
        let changed = parking.tick(date: date)
        if changed { saveParking() }
        if parking.isRinging && (changed || date.timeIntervalSince(lastParkingSoundAt) >= 1) {
            signalSound(); lastParkingSoundAt = date
        }
    }
    func rotateHeritage(by delta: Double) {
        guard delta.isFinite else { return }
        if renderer.isParking { parking.rotate(by: delta, date: Date()); saveParking() }
        else if renderer.isNavitimer {
            slideRuleAngle = ParkingAlarm.normalized(slideRuleAngle + delta)
            defaults.set(slideRuleAngle, forKey: "slideRuleAngle")
        } else { return }
        // Rotation redraws the shared live layers; static textures remain cached.
        if clockView != nil { updateClock() }
        updateHeritageMenu()
    }
    @objc func rotateScaleLeft() { rotateHeritage(by: -1) }
    @objc func rotateScaleRight() { rotateHeritage(by: 1) }
    @objc func resetSlideRule() { guard renderer.isNavitimer else { return }; rotateHeritage(by: -slideRuleAngle) }
}
