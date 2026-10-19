import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    let library: ThemeLibrary
    var renderer: DialRenderer
    let defaults: UserDefaults
    var window: ClockWindow!
    var clockView: ClockView!
    var statusItem: NSStatusItem!
    var clockMenu: NSMenu!
    var themeMenu = NSMenu()
    var sizeMenu = NSMenu()
    var hapticMenu = NSMenu()
    var titleItem: NSMenuItem!
    var timer: Timer?
    var chronograph = Chronograph()
    var gshock: GShock
    var gshockServiceTimer: Timer?
    var lastGShockSoundAt = Date.distantPast
    let signalSound: () -> Void
    private var positionSaveTimer: Timer?
    private var isSleeping = false
    private var notificationObservers: [(center: NotificationCenter, token: NSObjectProtocol)] = []
    private let accessibilityFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = .autoupdatingCurrent
        return formatter
    }()
    var lastAccessibilitySecond = -1
    private var lastChronographSecond: TimeInterval = -1
    var aboutWindowController: AboutWindowController?
    var menuActions: [String: NSMenuItem] = [:]
    lazy var menuBarLogo = makeMenuBarLogo(active: false)
    lazy var menuBarLogoActive = makeMenuBarLogo(active: true)

    init(library: ThemeLibrary, renderer: DialRenderer, defaults: UserDefaults = .standard,
         gshock: GShock? = nil, signalSound: (() -> Void)? = nil) {
        self.library = library
        self.renderer = renderer
        self.defaults = defaults
        let saved = defaults.data(forKey: "gshockSettings").flatMap { try? JSONDecoder().decode(GShockSettings.self, from: $0) }
        self.gshock = gshock ?? GShock(settings: saved ?? GShockSettings())
        self.gshock.resynchronizeWallClock(date: Date())
        self.signalSound = signalSound ?? { NSSound(named: NSSound.Name("Ping"))?.play() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.register(defaults: ["diameter": 280, "showSeconds": true, "smooth": true,
                                      "aboveWindows": false, "locked": false, "showBezel": true,
                                      "hapticFeedback": HapticMode.generic.rawValue])
        makeMenu()
        let side = CGFloat(defaults.integer(forKey: "diameter")).clamped(to: 160...466)
        let initialSize = renderer.displaySize(width: side, showBezel: defaults.bool(forKey: "showBezel"))
        window = ClockWindow(contentRect: NSRect(origin: .zero, size: initialSize),
                             styleMask: [.borderless], backing: .buffered, defer: false)
        window.title = L("%@ · %@", L("Vremya"), renderer.theme.localizedTitle)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.animationBehavior = .none
        clockView = ClockView(renderer: renderer)
        clockView.hapticMode = hapticMode
        clockView.clockMenu = clockMenu
        clockView.onInteraction = { [weak self] action in self?.performInteraction(action) }
        clockView.onDragEnded = { [weak self] in self?.keepOnScreen(); self?.savePosition() }
        clockView.showSeconds = defaults.bool(forKey: "showSeconds")
        clockView.showBezel = defaults.bool(forKey: "showBezel")
        window.contentView = clockView
        if let saved = WindowGeometry.savedOrigin(defaults.array(forKey: "origin") as? [Double]) {
            window.setFrameOrigin(saved)
        } else { placeAtDefaultPosition() }
        keepOnScreen()
        applyWindowPreferences()
        window.orderFrontRegardless()
        startTimer()
        refreshGShockService()
        observe(.NSSystemClockDidChange) { $0.systemClockChanged() }
        observe(.NSSystemTimeZoneDidChange) { $0.systemClockChanged() }
        observe(NSApplication.didChangeScreenParametersNotification) { $0.screensChanged() }
        observe(.NSProcessInfoPowerStateDidChange) { $0.resynchronize() }
        let workspace = NSWorkspace.shared.notificationCenter
        observe(NSWorkspace.didWakeNotification, center: workspace) { $0.wakeFromSleep() }
        observe(NSWorkspace.willSleepNotification, center: workspace) { $0.pauseForSleep() }
        observe(NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, center: workspace) { $0.resynchronize() }
    }

    private func observe(_ name: Notification.Name, center: NotificationCenter = .default,
                         action: @escaping @MainActor (AppDelegate) -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                if let self { action(self) }
            }
        }
        notificationObservers.append((center, token))
    }

    func makeMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: 36)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusItemClicked(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.setAccessibilityCustomActions([
            NSAccessibilityCustomAction(name: L("Open clock settings"), target: self, selector: #selector(accessibilityShowMenu))
        ])
        clockMenu = makeClockMenu()
        // Keeping NSStatusItem.menu unset lets the button deliver both clicks.
        updateStatusItem()
    }

    func makeClockMenu() -> NSMenu {
        menuActions.removeAll()
        sizeMenu = NSMenu()
        clockMenu = NSMenu()
        clockMenu.autoenablesItems = false
        clockMenu.delegate = self
        titleItem = NSMenuItem(title: L("%@ · %ld h", renderer.theme.localizedTitle, renderer.theme.hourCycle), action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        clockMenu.addItem(titleItem)
        let interactionItem = NSMenuItem(title: L("Interaction"), action: nil, keyEquivalent: "")
        interactionItem.submenu = makeInteractionMenu()
        clockMenu.addItem(interactionItem)
        menuActions["interaction"] = interactionItem
        updateChronographMenu()
        clockMenu.addItem(.separator())
        themeMenu = makeThemeMenu()
        let themeItem = NSMenuItem(title: L("Theme"), action: nil, keyEquivalent: "")
        themeItem.submenu = themeMenu
        clockMenu.addItem(themeItem)

        let appearance = NSMenu(title: L("Appearance"))
        appearance.autoenablesItems = false
        appearance.delegate = self
        for size in [180, 240, 280, 360, 466] {
            let item = NSMenuItem(title: L("Width: %ld pt", size), action: #selector(resizeClock(_:)), keyEquivalent: "")
            item.tag = size
            item.target = self
            sizeMenu.addItem(item)
        }
        let sizeItem = NSMenuItem(title: L("Size"), action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        appearance.addItem(sizeItem)
        add("showBezel", L("Bezel and strap"), #selector(toggleBezel), to: appearance)
        appearance.addItem(.separator())
        add("showSeconds", L("Seconds hand"), #selector(toggleSeconds), to: appearance)
        add("smooth", L("Smooth movement"), #selector(toggleSmooth), to: appearance)
        let appearanceItem = NSMenuItem(title: L("Appearance"), action: nil, keyEquivalent: "")
        appearanceItem.submenu = appearance
        clockMenu.addItem(appearanceItem)

        let windowMenu = NSMenu(title: L("Window"))
        windowMenu.autoenablesItems = false
        windowMenu.delegate = self
        add("aboveWindows", L("Always on top"), #selector(toggleAbove), to: windowMenu)
        add("locked", L("Lock position"), #selector(toggleLocked), to: windowMenu)
        windowMenu.addItem(.separator())
        add("reset", L("Return to screen"), #selector(resetPosition), to: windowMenu)
        let windowItem = NSMenuItem(title: L("Window"), action: nil, keyEquivalent: "")
        windowItem.submenu = windowMenu
        clockMenu.addItem(windowItem)
        hapticMenu = NSMenu(title: L("Haptic feedback"))
        hapticMenu.autoenablesItems = false
        hapticMenu.delegate = self
        for mode in HapticMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(selectHapticMode(_:)), keyEquivalent: "")
            item.representedObject = mode.rawValue
            item.target = self
            hapticMenu.addItem(item)
        }
        let hapticItem = NSMenuItem(title: L("Haptic feedback"), action: nil, keyEquivalent: "")
        hapticItem.submenu = hapticMenu
        hapticItem.toolTip = L("Trackpad feedback when hovering over mechanical watch buttons.")
        clockMenu.addItem(hapticItem)
        updateHapticMenuSelection()
        clockMenu.addItem(.separator())
        add("launchAtLogin", L("Launch at login"), #selector(toggleLaunchAtLogin))
        add("approveLaunchAtLogin", L("Allow launch at login in macOS…"), #selector(openLoginSettings))
        menuActions["approveLaunchAtLogin"]?.isHidden = true
        clockMenu.addItem(.separator())
        add("about", L("About…"), #selector(showAbout))
        add("quit", L("Quit"), #selector(quitApp), key: "q")
        return clockMenu
    }

    private func makeInteractionMenu() -> NSMenu {
        let menu = NSMenu(title: L("Interaction"))
        menu.autoenablesItems = false
        menu.delegate = self
        add("chronoToggle", L("Start chronograph"), #selector(toggleChronograph), to: menu)
        add("chronoReset", L("Reset chronograph"), #selector(resetChronograph), to: menu)
        let divider = NSMenuItem.separator()
        menu.addItem(divider)
        menuActions["chronoDivider"] = divider
        let elapsed = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        elapsed.isEnabled = false
        menu.addItem(elapsed)
        menuActions["chronoElapsed"] = elapsed
        addGShockMenuItems(to: menu)
        return menu
    }

    func makeThemeMenu() -> NSMenu {
        let menu = NSMenu()
        let raketa = NSMenu(title: L("Raketa"))
        let icons = NSMenu(title: L("Legendary models"))
        menu.autoenablesItems = false
        raketa.autoenablesItems = false
        icons.autoenablesItems = false
        for theme in library.catalog.themes {
            let item = NSMenuItem(title: theme.localizedTitle, action: #selector(selectTheme(_:)), keyEquivalent: "")
            item.representedObject = theme.id
            item.target = self
            (theme.isRaketa ? raketa : theme.isIcon ? icons : menu).addItem(item)
        }
        if !icons.items.isEmpty {
            menu.addItem(.separator())
            let group = NSMenuItem(title: L("Legendary models"), action: nil, keyEquivalent: "")
            group.submenu = icons
            menu.addItem(group)
        }
        if !raketa.items.isEmpty {
            if !menu.items.isEmpty { menu.addItem(.separator()) }
            let group = NSMenuItem(title: L("Raketa"), action: nil, keyEquivalent: "")
            let image = NSImage(contentsOf: library.resources.appendingPathComponent("RaketaLogo.png"))
            image?.size = NSSize(width: 60, height: 14.5)
            image?.isTemplate = false
            group.image = image
            group.submenu = raketa
            menu.addItem(group)
        }
        return menu
    }

    func updateThemeMenuSelection(_ menu: NSMenu) {
        for item in menu.items {
            if let submenu = item.submenu {
                updateThemeMenuSelection(submenu)
                item.state = submenu.items.contains { $0.state == .on } ? .on : .off
            } else {
                item.state = (item.representedObject as? String) == renderer.theme.id ? .on : .off
            }
        }
    }

    @objc func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showClockMenu(sender)
        } else {
            toggleAbove()
        }
    }
    private func showClockMenu(_ sender: NSStatusBarButton) {
        menuNeedsUpdate(clockMenu)
        sender.highlight(true)
        defer { sender.highlight(false) }
        clockMenu.popUp(positioning: nil, at: NSPoint(x: sender.bounds.minX, y: sender.bounds.minY - 4), in: sender)
    }
    @objc private func accessibilityShowMenu() -> Bool {
        guard let button = statusItem.button else { return false }
        showClockMenu(button)
        return true
    }

    func updateStatusItem() {
        let above = defaults.bool(forKey: "aboveWindows")
        let state = above ? L("on") : L("off")
        statusItem.button?.image = above ? menuBarLogoActive : menuBarLogo
        statusItem.button?.toolTip = L("%@ · Always on top: %@\nLeft-click to toggle. Right-click for the menu.", renderer.theme.localizedTitle, state)
        statusItem.button?.setAccessibilityLabel(L("%@ · %@", L("Vremya"), renderer.theme.localizedTitle))
        statusItem.button?.setAccessibilityValue(L("Always on top: %@", state))
        statusItem.button?.setAccessibilityHelp(L("Click to toggle always on top. Right-click or Control-click to open settings."))
    }

    func makeMenuBarLogo(active: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 24, height: 18))
        let name = active ? "MenuBarIconActive" : "MenuBarIcon"
        for scale in [1, 2, 3] {
            let suffix = scale == 1 ? "" : "@\(scale)x"
            let url = library.resources.appendingPathComponent(name + suffix + ".png")
            guard let data = try? Data(contentsOf: url),
                  let representation = NSBitmapImageRep(data: data) else { continue }
            representation.size = image.size
            image.addRepresentation(representation)
        }
        if image.representations.isEmpty {
            // Keep the menu accessible even if an installation lost its icon files.
            return NSImage(systemSymbolName: "clock", accessibilityDescription: L("Vremya")) ?? image
        }
        image.isTemplate = true
        return image
    }

    func add(_ id: String, _ title: String, _ action: Selector, key: String = "", to menu: NSMenu? = nil) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        (menu ?? clockMenu).addItem(item)
        menuActions[id] = item
    }
    func menuNeedsUpdate(_ menu: NSMenu) {
        updateChronographMenu()
        updateHapticMenuSelection()
        let loginStatus = SMAppService.mainApp.status
        menuActions["launchAtLogin"]?.state = loginStatus == .enabled ? .on :
            loginStatus == .requiresApproval ? .mixed : .off
        menuActions["launchAtLogin"]?.toolTip = loginStatus == .requiresApproval ?
            L("Launch at login is registered but needs macOS approval. Choose Allow launch at login in macOS… or click here to cancel.") :
            L("Start the clock automatically after you log in to macOS.")
        menuActions["approveLaunchAtLogin"]?.isHidden = loginStatus != .requiresApproval
        for key in ["aboveWindows", "locked", "showSeconds", "smooth", "showBezel"] {
            menuActions[key]?.state = defaults.bool(forKey: key) ? .on : .off
        }
        menuActions["showSeconds"]?.isEnabled = renderer.hasSeconds
        menuActions["showBezel"]?.isEnabled = renderer.hasBezel
        menuActions["showBezel"]?.state = renderer.hasBezel && defaults.bool(forKey: "showBezel") ? .on : .off
        menuActions["smooth"]?.isEnabled = (renderer.hasSeconds && defaults.bool(forKey: "showSeconds")) ||
            (renderer.hasChronograph && chronograph.isRunning)
        updateThemeMenuSelection(themeMenu)
        for item in sizeMenu.items {
            item.state = item.tag == defaults.integer(forKey: "diameter") ? .on : .off
        }
    }

    var hapticMode: HapticMode {
        HapticMode(rawValue: defaults.string(forKey: "hapticFeedback") ?? "") ?? .generic
    }
    private func updateHapticMenuSelection() {
        for item in hapticMenu.items {
            item.state = (item.representedObject as? String) == hapticMode.rawValue ? .on : .off
        }
    }
    @objc func selectHapticMode(_ item: NSMenuItem) {
        guard let rawValue = item.representedObject as? String, let mode = HapticMode(rawValue: rawValue) else { return }
        defaults.set(mode.rawValue, forKey: "hapticFeedback")
        clockView?.hapticMode = mode
        updateHapticMenuSelection()
    }

    func applyWindowPreferences() {
        window.level = defaults.bool(forKey: "aboveWindows") ? .floating :
            NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        window.ignoresMouseEvents = defaults.bool(forKey: "locked")
        updateStatusItem()
    }
    func startTimer() {
        timer?.invalidate()
        timer = nil
        updateClock()
        guard !isSleeping, window.occlusionState.contains(.visible) else { return }
        var interval = AnimationPolicy.interval(smooth: defaults.bool(forKey: "smooth"), showSeconds: defaults.bool(forKey: "showSeconds") ||
            (renderer.hasChronograph && chronograph.isRunning),
            hasSeconds: renderer.hasSeconds, reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled)
        if renderer.isGShock && gshock.needsFastRefresh {
            interval = gshock.isEditing ? 0.25 :
                (ProcessInfo.processInfo.isLowPowerModeEnabled || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.1 : 1.0 / 60)
        }
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            // This timer is registered exclusively on the main run loop.
            MainActor.assumeIsolated {
                guard let self else { return }
                self.updateClock()
                if self.renderer.isGShock && !self.gshock.needsFastRefresh && (self.timer?.timeInterval ?? 1) < 1 {
                    self.startTimer()
                }
            }
        }
        timer.tolerance = interval * 0.15
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
    func updateClock() {
        clockView.date = Date()
        advanceGShock(date: clockView.date)
        clockView.gshockDisplay = renderer.isGShock ? gshock.display(date: clockView.date,
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion) : nil
        clockView.chronographIsRunning = chronograph.isRunning
        clockView.chronograph = chronograph.reading
        clockView.needsDisplay = true
        let second = Calendar.current.component(.second, from: clockView.date)
        let chronoSecond = clockView.chronograph.elapsed.rounded(.down)
        if second != lastAccessibilitySecond || (renderer.hasChronograph && chronoSecond != lastChronographSecond) {
            lastAccessibilitySecond = second
            lastChronographSecond = chronoSecond
            let time = accessibilityFormatter.string(from: clockView.date)
            clockView.setAccessibilityValue(renderer.hasChronograph ? time + ", " + chronographDescription :
                renderer.isGShock ? time + ", " + gshockDescription : time)
            updateChronographMenu()
        }
    }
    private var chronographDescription: String {
        let state = chronograph.isRunning ? L("Running") : chronograph.reading.elapsed > 0 ? L("Paused") : L("Ready")
        return L("Chronograph: %@ · %@", chronograph.reading.text, state)
    }
    func updateChronographMenu() {
        menuActions["interaction"]?.isHidden = !renderer.hasChronograph && !renderer.isGShock && !gshock.isRinging
        for key in ["chronoToggle", "chronoReset", "chronoDivider", "chronoElapsed"] {
            menuActions[key]?.isHidden = !renderer.hasChronograph
        }
        menuActions["chronoToggle"]?.title = chronograph.isRunning ? L("Pause chronograph") : chronograph.reading.elapsed > 0 ? L("Resume chronograph") : L("Start chronograph")
        menuActions["chronoReset"]?.isEnabled = chronograph.isRunning || chronograph.reading.elapsed > 0
        menuActions["chronoElapsed"]?.title = chronographDescription
        updateGShockMenu()
    }
    func performInteraction(_ action: DialSpecification.MechanicalAction) {
        switch action {
        case .chronographToggle: toggleChronograph()
        case .chronographReset: resetChronograph()
        case .gshockA: pressGShock(.a)
        case .gshockB: pressGShock(.b)
        case .gshockC: pressGShock(.c)
        case .gshockD: pressGShock(.d)
        case .gshockFlash: pressGShock(.b, long: true)
        }
    }
    @objc func toggleChronograph() {
        guard renderer.hasChronograph else { return }
        if chronograph.isRunning { chronograph.pause() } else { chronograph.start() }
        lastAccessibilitySecond = -1
        updateChronographMenu()
        startTimer()
    }
    @objc func resetChronograph() {
        guard renderer.hasChronograph else { return }
        chronograph.reset()
        lastAccessibilitySecond = -1
        updateChronographMenu()
        startTimer()
    }
    @objc func resynchronize() { lastAccessibilitySecond = -1; startTimer() }
    func systemClockChanged() { gshock.resynchronizeWallClock(date: Date()); resynchronize() }
    @objc func pauseForSleep() {
        isSleeping = true; timer?.invalidate(); timer = nil
        gshockServiceTimer?.invalidate(); gshockServiceTimer = nil
        savePosition()
    }
    @objc func wakeFromSleep() { isSleeping = false; resynchronize(); refreshGShockService() }
    @objc func screensChanged() { resizeForTheme(width: preferredWidth); startTimer() }
    func windowDidChangeOcclusionState(_ notification: Notification) {
        guard clockView != nil else { return }
        startTimer()
    }
    func windowDidMove(_ notification: Notification) {
        positionSaveTimer?.invalidate()
        positionSaveTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.savePosition() }
        }
    }
    func savePosition() {
        positionSaveTimer?.invalidate()
        positionSaveTimer = nil
        guard let window else { return }
        defaults.set([window.frame.origin.x, window.frame.origin.y], forKey: "origin")
    }
    func placeAtDefaultPosition() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let frame = screen.visibleFrame
        window.setFrameOrigin(NSPoint(x: frame.maxX - window.frame.width - 32,
                                      y: frame.maxY - window.frame.height - 32))
    }
    func keepOnScreen() {
        let frame = WindowGeometry.fitted(window.frame, to: NSScreen.screens.map(\.visibleFrame))
        if frame != window.frame { window.setFrame(frame, display: true) }
    }
    private var preferredWidth: CGFloat { CGFloat(defaults.integer(forKey: "diameter")).clamped(to: 160...466) }

    @objc func resizeClock(_ item: NSMenuItem) {
        defaults.set(item.tag, forKey: "diameter")
        resizeForTheme(width: CGFloat(item.tag))
    }
    func resizeForTheme(width: CGFloat) {
        let center = NSPoint(x: window.frame.midX, y: window.frame.midY)
        let size = renderer.displaySize(width: width, showBezel: clockView.showBezel)
        window.setFrame(NSRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height), display: true)
        keepOnScreen()
    }
    @objc func toggleAbove() { toggle("aboveWindows"); applyWindowPreferences() }
    @objc func selectTheme(_ item: NSMenuItem) {
        guard let id = item.representedObject as? String else { return }
        let selected: DialRenderer
        do { selected = try library.renderer(for: id) } catch {
            let alert = NSAlert(); alert.messageText = L("Could not open theme")
            alert.informativeText = String(describing: error); alert.addButton(withTitle: L("OK")); alert.runModal(); return
        }
        renderer = selected
        defaults.set(id, forKey: "themeID")
        clockView.renderer = selected
        clockView.updateThemeDescription()
        window.title = L("%@ · %@", L("Vremya"), selected.theme.localizedTitle)
        updateStatusItem()
        titleItem.title = L("%@ · %ld h", selected.theme.localizedTitle, selected.theme.hourCycle)
        resizeForTheme(width: preferredWidth)
        lastAccessibilitySecond = -1
        startTimer()
    }
    @objc func toggleLocked() { toggle("locked"); applyWindowPreferences() }
    @objc func toggleBezel() {
        guard renderer.hasBezel else { return }
        toggle("showBezel")
        clockView.showBezel = defaults.bool(forKey: "showBezel")
        resizeForTheme(width: preferredWidth)
        updateClock()
    }
    @objc func toggleSeconds() {
        toggle("showSeconds")
        clockView.showSeconds = defaults.bool(forKey: "showSeconds")
        startTimer()
    }
    @objc func toggleSmooth() { toggle("smooth"); startTimer() }
    @objc func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            switch service.status {
            case .enabled, .requiresApproval:
                try service.unregister()
            case .notRegistered, .notFound:
                try service.register()
                if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
            @unknown default:
                SMAppService.openSystemSettingsLoginItems()
            }
        } catch {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = L("Could not change launch at login")
            alert.informativeText = L("%@\n\nMove the app to Applications and open it there. Launch at login is also available in System Settings → General → Login Items.", error.localizedDescription)
            alert.addButton(withTitle: L("OK"))
            alert.addButton(withTitle: L("Open settings"))
            if alert.runModal() == .alertSecondButtonReturn { SMAppService.openSystemSettingsLoginItems() }
        }
        menuNeedsUpdate(clockMenu)
    }
    @objc func openLoginSettings() { SMAppService.openSystemSettingsLoginItems() }
    func toggle(_ key: String) { defaults.set(!defaults.bool(forKey: key), forKey: key) }
    @objc func resetPosition() {
        defaults.set(false, forKey: "locked")
        applyWindowPreferences()
        placeAtDefaultPosition()
        keepOnScreen()
        window.orderFrontRegardless()
        startTimer()
    }
    @objc func showAbout() {
        if aboutWindowController == nil {
            aboutWindowController = AboutWindowController(resources: library.resources, themeCount: library.catalog.themes.count,
                raketaCount: library.catalog.themes.filter(\.isRaketa).count)
        }
        NSApp.activate(ignoringOtherApps: true)
        aboutWindowController?.showWindow(nil)
        aboutWindowController?.window?.makeKeyAndOrderFront(nil)
    }
    @objc func quitApp() { NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        keepOnScreen()
        window.orderFrontRegardless()
        startTimer()
        return false
    }
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        gshockServiceTimer?.invalidate()
        saveGShockSettings()
        savePosition()
        for observer in notificationObservers { observer.center.removeObserver(observer.token) }
        notificationObservers.removeAll()
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}
