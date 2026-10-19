import AppKit

@MainActor
func checkLocalizedInterface(library: ThemeLibrary, expectedLanguage: String) throws {
    expect(Localization.current.language == expectedLanguage, "Actual process language must follow the primary OS language")
    let expected = [
        "ru": ["Тема", "Поверх окон", "О часах", "Минимализм 24 — тёмный"],
        "en": ["Theme", "Always on top", "About", "Minimalism 24 — Dark"],
        "de": ["Zifferblatt", "Immer im Vordergrund", "Über Vremya", "Minimalismus 24 — dunkel"],
        "fr": ["Cadran", "Toujours au premier plan", "À propos", "Minimalisme 24 — sombre"],
        "es": ["Esfera", "Siempre visible", "Acerca de", "Minimalismo 24 — oscuro"]
    ][expectedLanguage]!
    let renderer = try library.renderer(for: "minimalism-24-dark")
    let suite = "local.vremya.localization-tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let delegate = AppDelegate(library: library, renderer: renderer, defaults: defaults)
    let menu = delegate.makeClockMenu()
    expect(menu.items.contains { $0.title == expected[0] }, "Main menu must be translated")
    expect(delegate.menuActions["aboveWindows"]?.title == expected[1], "Action labels must be translated")
    let feedbackTitles = [
        "ru": ["Тактильный отклик", "Выключен", "Обычный", "Выравнивание", "Смена уровня"],
        "en": ["Haptic feedback", "Disabled", "Generic", "Alignment", "Level change"],
        "de": ["Haptisches Feedback", "Aus", "Allgemein", "Ausrichtung", "Stufenwechsel"],
        "fr": ["Retour haptique", "Désactivé", "Général", "Alignement", "Changement de niveau"],
        "es": ["Respuesta háptica", "Desactivada", "General", "Alineación", "Cambio de nivel"]
    ][expectedLanguage]!
    expect(menu.items.contains { $0.title == feedbackTitles[0] } &&
           delegate.hapticMenu.items.map(\.title) == Array(feedbackTitles.dropFirst()), "Feedback choices must be localized")
    expect(delegate.titleItem.title.contains(expected[3]), "Current theme title must be translated")
    expect(delegate.themeMenu.items.first { $0.representedObject as? String == renderer.theme.id }?.title == expected[3],
           "Theme selection must use localized display names without changing IDs")
    delegate.menuNeedsUpdate(menu)
    expect(delegate.menuActions["launchAtLogin"]?.toolTip == L("Start the clock automatically after you log in to macOS.") ||
           delegate.menuActions["approveLaunchAtLogin"]?.isHidden == false, "Login hints must be translated")
    delegate.renderer = try library.renderer(for: "omega-speedmaster")
    delegate.menuNeedsUpdate(menu)
    expect(delegate.menuActions["interaction"]?.title == L("Interaction") &&
           delegate.menuActions["interaction"]?.isHidden == false &&
           delegate.menuActions["chronoToggle"]?.title == L("Start chronograph") &&
           delegate.menuActions["chronoReset"]?.title == L("Reset chronograph"), "Chronograph controls must be localized")
    let clock = ClockView(renderer: renderer)
    expect(clock.accessibilityLabel()?.contains(expected[3]) == true, "VoiceOver must use the translated theme")
    expect(clock.toolTip?.contains("24") == true, "Tooltip format arguments must be substituted")
    let about = AboutWindowController(resources: library.resources, themeCount: library.catalog.themes.count, raketaCount: 21)
    defer { about.close() }
    expect(about.window?.title == expected[2], "About title must be translated")
    for width in [640, 960] {
        for appearance in [NSAppearance.Name.aqua, .darkAqua] {
            about.window!.appearance = NSAppearance(named: appearance)
            about.window!.setContentSize(NSSize(width: width, height: 760))
            about.window!.contentView!.layoutSubtreeIfNeeded()
            let document = about.scrollView.documentView!
            document.layoutSubtreeIfNeeded()
            for child in about.contentStack.arrangedSubviews {
                let frame = child.convert(child.bounds, to: document)
                expect(frame.minX >= 0 && frame.maxX <= document.bounds.width + 1 && frame.height > 0 &&
                       frame.minY >= 0 && frame.maxY <= document.bounds.height + 1,
                       "Translated About layout must fit: \(expectedLanguage), width \(width)")
            }
        }
    }
    // Capture only this app's own unshown view for visual review, never the screen.
    about.window!.setContentSize(NSSize(width: 640, height: 760))
    about.window!.appearance = NSAppearance(named: .aqua)
    about.window!.contentView!.layoutSubtreeIfNeeded()
    let content = about.window!.contentView!
    if let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) {
        content.effectiveAppearance.performAsCurrentDrawingAppearance { content.cacheDisplay(in: content.bounds, to: bitmap) }
        let url = URL(fileURLWithPath: "macos/.build/previews/about-\(expectedLanguage).png")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bitmap.representation(using: .png, properties: [:])!.write(to: url)
    }
    print("Passed: \(expectedLanguage) menu, theme names, tooltips, VoiceOver and light/dark About layouts at 640/960 pt")
}
