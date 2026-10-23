import AppKit

@MainActor
extension AppDelegate {
    func addGShockMenuItems(to menu: NSMenu) {
        let modes = NSMenu(title: L("Mode"))
        modes.autoenablesItems = false
        modes.delegate = self
        for mode in GShock.Mode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(selectGShockMode(_:)), keyEquivalent: "")
            item.representedObject = mode.rawValue
            item.target = self
            modes.addItem(item)
        }
        let modeItem = NSMenuItem(title: L("Mode"), action: nil, keyEquivalent: "")
        modeItem.submenu = modes
        menu.addItem(modeItem)
        menuActions["gshockModes"] = modeItem
        add("gshockA", L("A · Adjust / split / reset"), #selector(gshockButtonA), to: menu)
        add("gshockB", L("B · Start / stop / increment"), #selector(gshockButtonB), to: menu)
        add("gshockC", L("C · Mode / next field"), #selector(gshockButtonC), to: menu)
        add("gshockD", L("D · Light / format / auto-repeat"), #selector(gshockButtonD), to: menu)
        let divider = NSMenuItem.separator()
        menu.addItem(divider)
        menuActions["gshockDivider"] = divider
        let options = NSMenu(title: L("G-Shock settings"))
        options.autoenablesItems = false
        options.delegate = self
        add("gshockSetAlarm", L("Set alarm…"), #selector(configureGShockAlarm), to: options)
        add("gshockAlarm", L("Alarm enabled"), #selector(toggleGShockAlarm), to: options)
        add("gshockHourly", L("Hourly signal"), #selector(toggleGShockHourly), to: options)
        options.addItem(.separator())
        add("gshockSetTimer", L("Set countdown…"), #selector(configureGShockCountdown), to: options)
        add("gshockRepeat", L("Auto-repeat"), #selector(toggleGShockRepeat), to: options)
        options.addItem(.separator())
        add("gshock24Hour", L("24-hour format"), #selector(toggleGShockFormat), to: options)
        add("gshockFlash", L("Flash Alert"), #selector(toggleGShockFlash), to: options)
        add("gshockButtonSound", L("Button sound"), #selector(toggleGShockButtonSound), to: options)
        add("gshockButtonVolume", L("Button volume…"), #selector(configureGShockButtonVolume), to: options)
        let optionItem = NSMenuItem(title: L("G-Shock settings"), action: nil, keyEquivalent: "")
        optionItem.submenu = options
        menu.addItem(optionItem)
        menuActions["gshockOptions"] = optionItem
        add("gshockSilence", L("Stop alarm sound"), #selector(silenceGShock), to: menu)
        let status = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menuActions["gshockStatus"] = status
    }

    var gshockDescription: String {
        let fields = gshock.display(date: clockView?.date ?? Date(), reduceMotion: true).fields
        let reading = [fields["hours"]!, fields["minutes"]!, fields["seconds"]!]
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.joined(separator: ":")
        return L("%@: %@", gshock.mode.title, reading)
    }
    func updateGShockMenu() {
        for (key, item) in menuActions where key.hasPrefix("gshock") { item.isHidden = !renderer.isGShock }
        guard renderer.isGShock else {
            if gshock.isRinging {
                menuActions["gshockSilence"]?.isHidden = false
                menuActions["gshockStatus"]?.isHidden = false
                menuActions["gshockDivider"]?.isHidden = !renderer.hasChronograph
                menuActions["gshockStatus"]?.title = gshock.alert == .alarm ? L("Alarm") :
                    gshock.alert == .countdown ? L("Countdown timer") : L("Hourly signal")
            }
            return
        }
        for item in menuActions["gshockModes"]?.submenu?.items ?? [] {
            item.state = (item.representedObject as? String) == gshock.mode.rawValue ? .on : .off
        }
        for (key, enabled) in [("gshockAlarm", gshock.settings.alarmEnabled), ("gshockHourly", gshock.settings.hourlySignal),
                               ("gshockRepeat", gshock.settings.autoRepeat), ("gshock24Hour", gshock.settings.use24Hour),
                               ("gshockFlash", gshock.settings.flashAlert), ("gshockButtonSound", gshockButtonSoundEnabled)] {
            menuActions[key]?.state = enabled ? .on : .off
        }
        menuActions["gshockSilence"]?.isHidden = !gshock.isRinging
        menuActions["gshockStatus"]?.title = gshockDescription
    }
    func saveGShockSettings() {
        if let data = try? JSONEncoder().encode(gshock.settings) { defaults.set(data, forKey: "gshockSettings") }
    }
    func advanceGShock(date: Date) {
        let previousAlert = gshock.alert
        let event = gshock.tick(date: date)
        // A consumed deadline must not ring again on every relaunch. No per-frame writes.
        if event != nil || previousAlert != gshock.alert { saveStopwatches() }
        if gshock.isRinging && (event != nil || date.timeIntervalSince(lastGShockSoundAt) >= 1) {
            signalSound()
            lastGShockSoundAt = date
        }
        if !gshock.needsService && !parking.needsService { gshockServiceTimer?.invalidate(); gshockServiceTimer = nil }
    }
    func refreshGShockService() {
        guard gshock.needsService || parking.needsService else { gshockServiceTimer?.invalidate(); gshockServiceTimer = nil; return }
        guard gshockServiceTimer == nil else { return }
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.advanceParking(date: Date())
                self.advanceGShock(date: Date())
                self.updateChronographMenu()
            }
        }
        timer.tolerance = 0.05
        RunLoop.main.add(timer, forMode: .common)
        gshockServiceTimer = timer
    }
    func applyGShockSettings(_ settings: GShockSettings) {
        guard settings.isValid else { return }
        gshock.configure(settings)
        finishGShockInteraction()
    }
    private func finishGShockInteraction() {
        saveGShockSettings()
        saveStopwatches()
        refreshGShockService()
        updateChronographMenu()
        lastAccessibilitySecond = -1
        if clockView != nil && window != nil { startTimer() }
    }
    func pressGShock(_ button: GShock.Button, long: Bool = false) {
        guard renderer.isGShock else { return }
        // Resolve due timers without replaying a signal immediately before the user silences it.
        gshock.tick(date: Date())
        let silencing = gshock.isRinging
        let accepted = !long || (button == .b && gshock.mode == .time && !gshock.isEditing)
        gshock.press(button, long: long)
        if !silencing && accepted { playGShockButtonSound() }
        finishGShockInteraction()
    }
    @objc func selectGShockMode(_ item: NSMenuItem) {
        guard renderer.isGShock, let value = item.representedObject as? String,
              let mode = GShock.Mode(rawValue: value) else { return }
        gshock.selectMode(mode)
        playGShockButtonSound()
        finishGShockInteraction()
    }
    static func makeGShockButtonSound(resources: URL) -> NSSound? {
        NSSound(contentsOf: resources.appendingPathComponent("GShockButton.wav"), byReference: false)
    }
    var gshockButtonSoundEnabled: Bool {
        defaults.object(forKey: "gshockButtonSound") as? Bool ?? true
    }
    var gshockButtonVolume: Float {
        let value = (defaults.object(forKey: "gshockButtonVolume") as? NSNumber)?.floatValue ?? 1
        return value.isFinite ? min(max(value, 0), 1) : 1
    }
    func setGShockButtonVolume(_ value: Float) {
        guard value.isFinite else { return }
        defaults.set(min(max(value, 0), 1), forKey: "gshockButtonVolume")
    }
    private func playGShockButtonSound() {
        if gshockButtonSoundEnabled && gshockButtonVolume > 0 { buttonSound(gshockButtonVolume) }
    }
    @objc func toggleGShockButtonSound() {
        defaults.set(!gshockButtonSoundEnabled, forKey: "gshockButtonSound")
        updateGShockMenu()
    }
    @objc func configureGShockButtonVolume() {
        let form = GShockButtonVolumeForm(volume: gshockButtonVolume)
        let dialog = NSAlert()
        dialog.messageText = L("Button volume…")
        dialog.accessoryView = form.view
        dialog.addButton(withTitle: L("Save"))
        dialog.addButton(withTitle: L("Cancel"))
        dialog.window.initialFirstResponder = form.slider
        NSApp.activate(ignoringOtherApps: true)
        if dialog.runModal() == .alertFirstButtonReturn { setGShockButtonVolume(form.volume) }
    }
    @objc func gshockButtonA() { pressGShock(.a) }
    @objc func gshockButtonB() { pressGShock(.b) }
    @objc func gshockButtonC() { pressGShock(.c) }
    @objc func gshockButtonD() { pressGShock(.d) }
    @objc func toggleGShockAlarm() { var s = gshock.settings; s.alarmEnabled.toggle(); applyGShockSettings(s) }
    @objc func toggleGShockHourly() { var s = gshock.settings; s.hourlySignal.toggle(); applyGShockSettings(s) }
    @objc func toggleGShockRepeat() { var s = gshock.settings; s.autoRepeat.toggle(); applyGShockSettings(s) }
    @objc func toggleGShockFormat() { var s = gshock.settings; s.use24Hour.toggle(); applyGShockSettings(s) }
    @objc func toggleGShockFlash() { var s = gshock.settings; s.flashAlert.toggle(); applyGShockSettings(s) }
    @objc func silenceGShock() { gshock.silence(); finishGShockInteraction() }
    @objc func configureGShockAlarm() { showGShockSettings(alarm: true) }
    @objc func configureGShockCountdown() { showGShockSettings(alarm: false) }
    private func showGShockSettings(alarm: Bool) {
        let form = GShockSettingsForm(settings: gshock.settings, alarm: alarm)
        let dialog = NSAlert()
        dialog.messageText = alarm ? L("Set alarm…") : L("Set countdown…")
        dialog.informativeText = L("Alarms sound while the app is running. A sleeping Mac is not woken; overdue timers and alarms are checked after wake.")
        dialog.accessoryView = form.view
        dialog.addButton(withTitle: L("Save"))
        dialog.addButton(withTitle: L("Cancel"))
        NSApp.activate(ignoringOtherApps: true)
        while dialog.runModal() == .alertFirstButtonReturn {
            if let settings = form.selectedSettings {
                gshock.selectMode(alarm ? .alarm : .countdown)
                applyGShockSettings(settings)
                return
            }
            dialog.informativeText = L("Check the alarm date or choose a countdown from 1 second to 24 hours.")
        }
    }
}

@MainActor
final class GShockButtonVolumeForm: NSObject {
    let slider: NSSlider
    let readout = NSTextField(labelWithString: "")
    let view: NSStackView
    var volume: Float { Float(slider.doubleValue.rounded() / 100) }

    init(volume: Float) {
        slider = NSSlider(value: Double(volume) * 100, minValue: 0, maxValue: 100, target: nil, action: nil)
        view = NSStackView(views: [slider, readout])
        super.init()
        view.orientation = .horizontal
        view.alignment = .centerY
        view.spacing = 12
        slider.widthAnchor.constraint(equalToConstant: 220).isActive = true
        readout.widthAnchor.constraint(equalToConstant: 46).isActive = true
        readout.alignment = .right
        slider.setAccessibilityLabel(L("Button volume"))
        slider.target = self
        slider.action = #selector(volumeChanged)
        volumeChanged()
        view.frame.size = view.fittingSize
    }
    @objc func volumeChanged() {
        slider.doubleValue = slider.doubleValue.rounded()
        readout.stringValue = "\(Int(slider.doubleValue))%"
    }
}

@MainActor
final class GShockSettingsForm {
    let view: NSGridView
    let fields: [NSPopUpButton]
    let alarm: Bool
    private let settings: GShockSettings

    init(settings: GShockSettings, alarm: Bool) {
        self.settings = settings
        self.alarm = alarm
        let values = alarm ? [settings.alarmHour, settings.alarmMinute, settings.alarmMonth, settings.alarmDay] :
            [settings.countdownSeconds / 3600, settings.countdownSeconds / 60 % 60, settings.countdownSeconds % 60]
        let limits = alarm ? [23, 59, 12, 31] : [24, 59, 59]
        let labels = alarm ? [L("Hour (0–23)"), L("Minute"), L("Month (0 = any)"), L("Day (0 = any)")] :
            [L("Hour"), L("Minute"), L("Second")]
        let controls = limits.enumerated().map { index, limit in
            let field = NSPopUpButton(frame: .zero, pullsDown: false)
            field.addItems(withTitles: (0...limit).map { String($0) })
            field.selectItem(at: values[index])
            field.setAccessibilityLabel(labels[index])
            return field
        }
        fields = controls
        view = NSGridView(views: labels.enumerated().map { [NSTextField(labelWithString: $0.element), controls[$0.offset]] })
        view.rowSpacing = 10
        view.columnSpacing = 16
        view.column(at: 0).xPlacement = .trailing
        view.column(at: 1).width = 110
        view.frame.size = view.fittingSize
    }
    var selectedSettings: GShockSettings? {
        var updated = settings
        let values = fields.map(\.indexOfSelectedItem)
        if alarm {
            updated.alarmHour = values[0]; updated.alarmMinute = values[1]
            updated.alarmMonth = values[2]; updated.alarmDay = values[3]
            updated.alarmEnabled = true
        } else {
            let duration = values[0] * 3600 + values[1] * 60 + values[2]
            updated.countdownSeconds = duration == 0 ? 86_400 : duration
        }
        return updated.isValid ? updated : nil
    }
}
