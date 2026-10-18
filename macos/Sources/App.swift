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
    var titleItem: NSMenuItem!
    var timer: Timer?
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
    var aboutWindowController: AboutWindowController?
    var menuActions: [String: NSMenuItem] = [:]
    lazy var menuBarLogo = makeMenuBarLogo(active: false)
    lazy var menuBarLogoActive = makeMenuBarLogo(active: true)

    init(library: ThemeLibrary, renderer: DialRenderer, defaults: UserDefaults = .standard) {
        self.library = library
        self.renderer = renderer
        self.defaults = defaults
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.register(defaults: ["diameter": 280, "showSeconds": true, "smooth": true,
                                      "aboveWindows": false, "locked": false, "showBezel": true])
        makeMenu()
        let side = CGFloat(defaults.integer(forKey: "diameter")).clamped(to: 160...466)
        let initialSize = renderer.displaySize(width: side, showBezel: defaults.bool(forKey: "showBezel"))
        window = ClockWindow(contentRect: NSRect(origin: .zero, size: initialSize),
                             styleMask: [.borderless], backing: .buffered, defer: false)
        window.title = "Время · \(renderer.theme.title)"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.animationBehavior = .none
        clockView = ClockView(renderer: renderer)
        clockView.clockMenu = clockMenu
        clockView.onToggleBezel = { [weak self] in self?.toggleBezel() }
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
        observe(.NSSystemClockDidChange) { $0.resynchronize() }
        observe(.NSSystemTimeZoneDidChange) { $0.resynchronize() }
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
            NSAccessibilityCustomAction(name: "Открыть настройки часов", target: self, selector: #selector(accessibilityShowMenu))
        ])
        clockMenu = NSMenu()
        clockMenu.autoenablesItems = false
        clockMenu.delegate = self
        titleItem = NSMenuItem(title: "\(renderer.theme.title) · \(renderer.theme.hourCycle) часов", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        clockMenu.addItem(titleItem)
        clockMenu.addItem(.separator())
        themeMenu = makeThemeMenu()
        let themeItem = NSMenuItem(title: "Тема", action: nil, keyEquivalent: "")
        themeItem.submenu = themeMenu
        clockMenu.addItem(themeItem)
        for size in [180, 240, 280, 360, 466] {
            let item = NSMenuItem(title: "Ширина \(size) пт", action: #selector(resizeClock(_:)), keyEquivalent: "")
            item.tag = size
            item.target = self
            sizeMenu.addItem(item)
        }
        let sizeItem = NSMenuItem(title: "Размер", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        clockMenu.addItem(sizeItem)
        add("aboveWindows", "Поверх окон", #selector(toggleAbove))
        add("locked", "Закрепить положение", #selector(toggleLocked))
        add("showBezel", "Безель и ремешок", #selector(toggleBezel))
        clockMenu.addItem(.separator())
        add("showSeconds", "Секундная стрелка", #selector(toggleSeconds))
        add("smooth", "Плавное движение", #selector(toggleSmooth))
        clockMenu.addItem(.separator())
        add("launchAtLogin", "Автозапуск при старте системы", #selector(toggleLaunchAtLogin))
        add("approveLaunchAtLogin", "Разрешить автозапуск в macOS…", #selector(openLoginSettings))
        menuActions["approveLaunchAtLogin"]?.isHidden = true
        clockMenu.addItem(.separator())
        add("reset", "Вернуть на видимое место", #selector(resetPosition))
        add("about", "О часах…", #selector(showAbout))
        add("quit", "Завершить", #selector(quitApp), key: "q")
        // Keeping NSStatusItem.menu unset lets the button deliver both clicks.
        updateStatusItem()
    }

    func makeThemeMenu() -> NSMenu {
        let menu = NSMenu()
        let raketa = NSMenu(title: "Ракета")
        menu.autoenablesItems = false
        raketa.autoenablesItems = false
        for theme in library.catalog.themes {
            let item = NSMenuItem(title: theme.title, action: #selector(selectTheme(_:)), keyEquivalent: "")
            item.representedObject = theme.id
            item.target = self
            (theme.isRaketa ? raketa : menu).addItem(item)
        }
        if !raketa.items.isEmpty {
            if !menu.items.isEmpty { menu.addItem(.separator()) }
            let group = NSMenuItem(title: "Ракета", action: nil, keyEquivalent: "")
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
        let state = above ? "включено" : "выключено"
        statusItem.button?.image = above ? menuBarLogoActive : menuBarLogo
        statusItem.button?.toolTip = "\(renderer.theme.title) · Поверх окон: \(state)\nЛевый клик — переключить. Правый клик — меню."
        statusItem.button?.setAccessibilityLabel("Время · \(renderer.theme.title)")
        statusItem.button?.setAccessibilityValue("Поверх окон: \(state)")
        statusItem.button?.setAccessibilityHelp("Нажмите, чтобы переключить режим поверх окон. Правый клик или Control-клик открывает настройки.")
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
            return NSImage(systemSymbolName: "clock", accessibilityDescription: "Время") ?? image
        }
        image.isTemplate = true
        return image
    }

    func add(_ id: String, _ title: String, _ action: Selector, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        clockMenu.addItem(item)
        menuActions[id] = item
    }
    func menuNeedsUpdate(_ menu: NSMenu) {
        let loginStatus = SMAppService.mainApp.status
        menuActions["launchAtLogin"]?.state = loginStatus == .enabled ? .on :
            loginStatus == .requiresApproval ? .mixed : .off
        menuActions["launchAtLogin"]?.toolTip = loginStatus == .requiresApproval ?
            "Автозапуск добавлен, но macOS ожидает разрешения. Выберите «Разрешить автозапуск в macOS…» или нажмите здесь, чтобы отменить." :
            "Запускать часы автоматически после входа в вашу учётную запись macOS."
        menuActions["approveLaunchAtLogin"]?.isHidden = loginStatus != .requiresApproval
        for key in ["aboveWindows", "locked", "showSeconds", "smooth", "showBezel"] {
            menuActions[key]?.state = defaults.bool(forKey: key) ? .on : .off
        }
        menuActions["showSeconds"]?.isEnabled = renderer.hasSeconds
        menuActions["showBezel"]?.isEnabled = renderer.hasBezel
        menuActions["showBezel"]?.state = renderer.hasBezel && defaults.bool(forKey: "showBezel") ? .on : .off
        menuActions["smooth"]?.isEnabled = renderer.hasSeconds && defaults.bool(forKey: "showSeconds")
        updateThemeMenuSelection(themeMenu)
        for item in sizeMenu.items {
            item.state = item.tag == defaults.integer(forKey: "diameter") ? .on : .off
        }
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
        let interval = AnimationPolicy.interval(smooth: defaults.bool(forKey: "smooth"), showSeconds: defaults.bool(forKey: "showSeconds"),
            hasSeconds: renderer.hasSeconds, reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
            lowPower: ProcessInfo.processInfo.isLowPowerModeEnabled)
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            // This timer is registered exclusively on the main run loop.
            MainActor.assumeIsolated { self?.updateClock() }
        }
        timer.tolerance = interval * 0.15
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
    func updateClock() {
        clockView.date = Date()
        clockView.needsDisplay = true
        let second = Calendar.current.component(.second, from: clockView.date)
        if second != lastAccessibilitySecond {
            lastAccessibilitySecond = second
            clockView.setAccessibilityValue(accessibilityFormatter.string(from: clockView.date))
        }
    }
    @objc func resynchronize() { lastAccessibilitySecond = -1; startTimer() }
    @objc func pauseForSleep() { isSleeping = true; timer?.invalidate(); timer = nil; savePosition() }
    @objc func wakeFromSleep() { isSleeping = false; resynchronize() }
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
            let alert = NSAlert(); alert.messageText = "Не удалось открыть тему"
            alert.informativeText = String(describing: error); alert.runModal(); return
        }
        renderer = selected
        defaults.set(id, forKey: "themeID")
        clockView.renderer = selected
        clockView.updateThemeDescription()
        window.title = "Время · \(selected.theme.title)"
        updateStatusItem()
        titleItem.title = "\(selected.theme.title) · \(selected.theme.hourCycle) часов"
        resizeForTheme(width: preferredWidth)
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
            alert.messageText = "Не удалось изменить автозапуск"
            alert.informativeText = "\(error.localizedDescription)\n\nПереместите приложение в «Программы» и откройте его оттуда. Автозапуск также доступен в «Системные настройки → Основные → Объекты входа»."
            alert.addButton(withTitle: "Понятно")
            alert.addButton(withTitle: "Открыть настройки")
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
        savePosition()
        for observer in notificationObservers { observer.center.removeObserver(observer.token) }
        notificationObservers.removeAll()
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}
