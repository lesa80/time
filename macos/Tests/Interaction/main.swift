import AppKit

@MainActor
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        FileHandle.standardError.write(Data(("Interaction test failed: " + message + "\n").utf8))
        exit(1)
    }
}

// Exercise actual view handlers with local events in an unshown window.
// No system events are posted and no user preferences are changed.
let application = NSApplication.shared
application.setActivationPolicy(.prohibited)
let library = try ThemeLibrary(resources: URL(fileURLWithPath: CommandLine.arguments[1]))
if let index = CommandLine.arguments.firstIndex(of: "--localization-only") {
    try checkLocalizedInterface(library: library, expectedLanguage: CommandLine.arguments[index + 1])
    exit(0)
}
let renderer = try library.renderer(for: "avangard")
let window = ClockWindow(contentRect: NSRect(x: 200, y: 200, width: 280, height: 280),
                         styleMask: [.borderless], backing: .buffered, defer: false)
window.isReleasedWhenClosed = false
let view = ClockView(renderer: renderer)
view.showBezel = false
window.contentView = view
var toggles = 0
view.onToggleBezel = { toggles += 1 }
@MainActor
func send(_ type: NSEvent.EventType, at point: NSPoint, flags: NSEvent.ModifierFlags = []) {
    let event = NSEvent.mouseEvent(with: type, location: window.convertPoint(fromScreen: point),
        modifierFlags: flags, timestamp: 0, windowNumber: window.windowNumber, context: nil,
        eventNumber: 0, clickCount: 1, pressure: type == .leftMouseUp ? 0 : 1)!
    switch type {
    case .leftMouseDown: view.mouseDown(with: event)
    case .leftMouseDragged: view.mouseDragged(with: event)
    case .leftMouseUp: view.mouseUp(with: event)
    case .rightMouseDown: view.rightMouseDown(with: event)
    default: fatalError("Unexpected test event")
    }
}
@MainActor
func center() -> NSPoint { window.convertPoint(toScreen: NSPoint(x: 140, y: 140)) }
let start = center()
send(.leftMouseDown, at: start)
send(.leftMouseUp, at: start)
expect(toggles == 1, "A single click must toggle the bezel")
send(.leftMouseUp, at: start)
expect(toggles == 1, "A release without a press must not toggle")

let originalFrame = window.frame
let slightMovement = NSPoint(x: start.x + 2, y: start.y + 1)
send(.leftMouseDown, at: start)
send(.leftMouseDragged, at: slightMovement)
send(.leftMouseUp, at: slightMovement)
expect(toggles == 2 && window.frame == originalFrame, "Pointer jitter must remain a click")

let moved = NSPoint(x: start.x + 36, y: start.y + 18)
send(.leftMouseDown, at: start)
send(.leftMouseDragged, at: moved)
expect(window.frame.origin == NSPoint(x: originalFrame.minX + 36, y: originalFrame.minY + 18),
             "Dragging must move the clock by the screen-space pointer displacement")
send(.leftMouseUp, at: moved)
expect(toggles == 2, "Dragging must not toggle the bezel")

let nextStart = center()
send(.leftMouseDown, at: nextStart)
send(.leftMouseDragged, at: NSPoint(x: nextStart.x + 20, y: nextStart.y))
send(.leftMouseDragged, at: nextStart)
send(.leftMouseUp, at: nextStart)
expect(toggles == 2, "Returning a drag to its starting point must not become a click")

send(.leftMouseDown, at: center(), flags: .control)
send(.leftMouseUp, at: center(), flags: .control)
send(.rightMouseDown, at: center())
expect(toggles == 2, "Context-menu clicks must not toggle the bezel")
send(.leftMouseDown, at: center())
send(.leftMouseUp, at: NSPoint(x: window.frame.maxX + 10, y: window.frame.maxY + 10))
expect(toggles == 2, "Releasing outside the clock must not toggle")
expect(view.accessibilityPerformPress() && toggles == 3, "VoiceOver press must toggle the bezel")
expect(view.acceptsFirstMouse(for: nil), "A click must work when the app is inactive")

// Compare the live view's static-layer cache against the uncached renderer.
// Render locally into bitmaps; no screen capture permission is involved.
@MainActor
func pixels(cached: Bool, renderer: DialRenderer, showBezel: Bool, width: CGFloat = 280) -> [UInt8] {
    let size = renderer.displaySize(width: width, showBezel: showBezel)
    window.setContentSize(size)
    // AppKit rounds window frames to pixels; explicitly exercise fractional view bounds too.
    view.setBoundsSize(size)
    view.renderer = renderer
    view.showBezel = showBezel
    view.showSeconds = false
    view.date = Date(timeIntervalSince1970: 1_700_000_000)
    let scale = window.backingScaleFactor
    let pixelWidth = Int(ceil(size.width * scale)), height = Int(ceil(size.height * scale))
    let bitmap = CGContext(data: nil, width: pixelWidth, height: height, bitsPerComponent: 8, bytesPerRow: pixelWidth * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    bitmap.scaleBy(x: CGFloat(pixelWidth) / size.width, y: CGFloat(height) / size.height)
    if cached {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: bitmap, flipped: false)
        view.draw(view.bounds)
        // A second frame exercises reuse rather than only cache initialization.
        bitmap.clear(CGRect(origin: .zero, size: size))
        view.draw(view.bounds)
        NSGraphicsContext.restoreGraphicsState()
    } else {
        renderer.draw(in: bitmap, size: size, angles: HandAngles(date: view.date,
            hourCycle: renderer.theme.hourCycle, direction: renderer.theme.rotationDirection), showSeconds: false, showBezel: showBezel)
    }
    return Array(UnsafeBufferPointer(start: bitmap.data!.assumingMemoryBound(to: UInt8.self), count: pixelWidth * height * 4))
}
let fractionalCached = pixels(cached: true, renderer: renderer, showBezel: true, width: 280.3)
let fractionalDirect = pixels(cached: false, renderer: renderer, showBezel: true, width: 280.3)
let fractionalError = zip(fractionalCached, fractionalDirect).reduce(0.0) { $0 + abs(Double($1.0) - Double($1.1)) } / Double(fractionalCached.count)
expect(fractionalError < 0.6, "Fractional-size cache alignment: \(fractionalError)")
for theme in library.catalog.themes {
    let renderer = try library.renderer(for: theme.id)
    for bezel in [true, false] {
        let cached = pixels(cached: true, renderer: renderer, showBezel: bezel)
        let direct = pixels(cached: false, renderer: renderer, showBezel: bezel)
        let difference = zip(cached, direct).reduce(0.0) { $0 + abs(Double($1.0) - Double($1.1)) } / Double(cached.count)
        expect(difference < 0.6, "Cached artwork differs from direct rendering: \(theme.id), bezel=\(bezel), error=\(difference)")
    }
}

let suite = "local.raketa.tests.\(UUID().uuidString)"
let preferences = UserDefaults(suiteName: suite)!
preferences.set(280, forKey: "diameter")
preferences.set(false, forKey: "showBezel")
let delegate = AppDelegate(library: library, renderer: renderer, defaults: preferences)
delegate.window = window
delegate.clockView = view
view.renderer = renderer
view.showBezel = false
delegate.toggleBezel()
expect(preferences.bool(forKey: "showBezel") && view.showBezel, "Toggle must save full-watch mode")
delegate.toggleBezel()
expect(!preferences.bool(forKey: "showBezel") && !view.showBezel, "Toggle must restore dial-only mode")
expect(abs(window.frame.width - 280) < 0.1, "Mode changes must retain the preferred width")
delegate.pauseForSleep()
expect(delegate.timer == nil, "System sleep must stop redraws")
// Exercise the actual menu builder without registering a system status item.
let menu = delegate.makeThemeMenu()
expect(menu.items.first?.representedObject as? String == "minimalism", "Own theme must be outside the Raketa section")
let brand = menu.items.first { $0.title == L("Raketa") }!
expect(brand.image != nil && brand.image?.isTemplate == false, "Brand section must keep the red logo")
expect(brand.submenu?.items.count == 21, "All manufacturer themes must be grouped")
delegate.updateThemeMenuSelection(menu)
expect(brand.state == .on && brand.submenu?.items.first { $0.representedObject as? String == "avangard" }?.state == .on,
       "Selection must be visible in the nested menu")
expect(menu.items.filter { $0.representedObject != nil }.map { $0.representedObject as! String } == ["minimalism", "minimalism-24", "minimalism-dark", "minimalism-24-dark"],
       "All own themes must be selectable outside the manufacturer section")
for id in ["minimalism", "minimalism-24", "minimalism-dark", "minimalism-24-dark"] {
    let minimalism = try library.renderer(for: id)
    delegate.renderer = minimalism
    view.renderer = minimalism
    view.showBezel = false
    expect(minimalism.hasBezel && minimalism.hasSeconds, "All Minimalism themes must have a case and seconds")
    delegate.toggleBezel()
    expect(preferences.bool(forKey: "showBezel") && view.showBezel, "Minimalism must save full-watch mode")
    delegate.toggleBezel()
    expect(!preferences.bool(forKey: "showBezel") && !view.showBezel, "Minimalism must restore dial-only mode")
    expect(view.hitTest(NSPoint(x: 0, y: 0)) == nil, "Dial-only corners must pass mouse input through")
    expect(view.accessibilityPerformPress(), "Minimalism must expose the bezel action to VoiceOver")
    expect(abs(minimalism.displaySize(width: 280, showBezel: false).height - 280) < 1,
           "All separate dials must remain circular")
    expect(minimalism.displaySize(width: 280, showBezel: true).height > 280,
           "All full watches must retain the strap proportions")
    delegate.updateThemeMenuSelection(menu)
    expect(menu.items.first { $0.representedObject as? String == id }?.state == .on && brand.state == .off,
           "Own-theme selection must clear branded selection")
}
for active in [false, true] {
    let icon = delegate.makeMenuBarLogo(active: active)
    expect(icon.isTemplate && icon.size == NSSize(width: 24, height: 18) && icon.representations.count == 3,
           "Neutral tray icon must use template rendering and three Retina representations")
}
let about = AboutWindowController(resources: library.resources, themeCount: library.catalog.themes.count, raketaCount: 21)
@MainActor
func descendants(_ root: NSView) -> [NSView] { [root] + root.subviews.flatMap { descendants($0) } }
let aboutViews = descendants(about.window!.contentView!)
expect(!aboutViews.contains { $0 is NSTabView }, "About must not contain tabs")
expect(aboutViews.filter { $0 is NSScrollView }.count == 1, "About must use a single scrollable page")
let headings = about.contentStack.arrangedSubviews.compactMap { $0.identifier?.rawValue }.filter { $0.hasPrefix("section-") }
expect(headings == ["section-help", "section-raketa", "section-licenses", "section-developer"], "About sections must follow reading order")
expect(aboutViews.contains { $0.identifier?.rawValue == "app-icon" && ($0 as? NSImageView)?.image != nil }, "About must show the supplied app icon")
let developerLogo = aboutViews.first { $0.identifier?.rawValue == "developer-logo" }!
expect(descendants(developerLogo).contains { ($0 as? NSImageView)?.image != nil }, "About must show the supplied developer logo")
for width in [960, 640] {
    for (mode, appearance) in [("light", NSAppearance.Name.aqua), ("dark", NSAppearance.Name.darkAqua)] {
        about.window!.appearance = NSAppearance(named: appearance)
        about.window!.setContentSize(NSSize(width: width, height: 760))
        about.window!.contentView!.layoutSubtreeIfNeeded()
        expect(abs(about.window!.contentView!.bounds.width - CGFloat(width)) < 1,
               "About window must retain requested width: \(width), actual \(about.window!.contentView!.bounds.width)")
        let scroll = about.scrollView
        let document = scroll.documentView!
        document.layoutSubtreeIfNeeded()
        expect(abs(document.bounds.width - scroll.contentView.bounds.width) < 1, "About content must fit each window width")
        expect(document.bounds.height > scroll.contentView.bounds.height, "All sections must remain in one vertically scrolling document")
        for child in about.contentStack.arrangedSubviews {
            let frame = child.convert(child.bounds, to: document)
            expect(frame.minX >= 0 && frame.maxX <= document.bounds.width + 1 && frame.height > 0 && frame.minY >= 0 && frame.maxY <= document.bounds.height + 1,
                   "About controls must fit scrollable content: width=\(width), mode=\(mode), document=\(document.frame), child=\(type(of: child)) \(frame)")
        }
        for bottom in [false, true] {
            scroll.contentView.scroll(to: NSPoint(x: 0, y: bottom ? document.bounds.maxY - scroll.contentView.bounds.height : 0))
            scroll.reflectScrolledClipView(scroll.contentView)
            about.window!.contentView!.layoutSubtreeIfNeeded()
            if bottom {
                let frame = developerLogo.convert(developerLogo.bounds, to: document)
                expect(scroll.contentView.bounds.minY > 0 && scroll.documentVisibleRect.intersects(frame), "Developer section must be reachable by scrolling")
            } else {
                expect(abs(scroll.contentView.bounds.minY) < 1, "About must scroll back to the app header")
            }
            // Render this app's own unshown view only, without screen capture.
            let position = bottom ? "bottom" : "top"
            let url = URL(fileURLWithPath: "macos/.build/previews/about-\(mode)-\(width)-\(position).png")
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let content = about.window!.contentView!
            if let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) {
                content.effectiveAppearance.performAsCurrentDrawingAppearance {
                    content.cacheDisplay(in: content.bounds, to: bitmap)
                }
                try bitmap.representation(using: .png, properties: [:])!.write(to: url)
            }
        }
    }
}
about.close()
preferences.removePersistentDomain(forName: suite)
window.close()
print("Passed: widget click, pointer jitter, drag, return drag, context click, outside release and accessibility press")
print("Passed: cached native rendering for \(library.catalog.themes.count) themes in both modes, saved bezel preference, preferred width and sleep pause")

print("Passed: neutral icons, grouped theme selection, all Minimalism case toggles, single-page About sections, supplied branding, light/dark layouts and scrolling")
