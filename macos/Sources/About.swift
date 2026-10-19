import AppKit

@MainActor
private final class AboutDocumentView: NSView {
    override var isFlipped: Bool { true }
    override var isOpaque: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            NSColor.windowBackgroundColor.setFill()
            dirtyRect.fill()
        }
    }
}

@MainActor
final class AboutWindowController: NSWindowController {
    let scrollView = NSScrollView()
    let contentStack = NSStackView()
    private var linkURLs: [ObjectIdentifier: URL] = [:]

    init(resources: URL, themeCount: Int, raketaCount: Int) {
        let visible = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 900)
        let size = NSSize(width: min(960, visible.width - 60), height: min(850, visible.height - 60))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = L("About")
        window.minSize = NSSize(width: 640, height: 480)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.contentView = scrollView
        configureContent()
        let content = contentStack
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.5.0"
        add(makeHeader(resources: resources, version: version), to: content)
        add(label(L("An independent, unofficial app. This project is not affiliated with or endorsed by the Raketa watch manufacturer.")), to: content)
        section(L("Quick help"), identifier: "section-help")
        add(label(L("Themes available: %ld. The clock shows local macOS time. Minimalism and Minimalism 24 are original 12- and 24-hour themes in light and dark variants. The default is Minimalism 24 — Dark; your saved selection takes priority.\n\nDrag the clock to move it. Use Appearance → Bezel and strap to change the display mode. Clicking the dial does not change its appearance.\n\nRight-click the clock or menu bar icon for settings. Appearance groups size, bezel and hand options; Window groups always on top, position lock and return to screen. Left-click the menu bar icon to toggle Always on top. Interaction appears directly under the model name when controls are available.\n\nLaunch at login starts the app after sign-in. Move the app to Applications first; macOS may require approval in General → Login Items.", themeCount)), to: content)
        section(L("Legendary models"), identifier: "section-icons")
        add(label(L("Legendary watch models and their color variants: Rolex Submariner, Omega Speedmaster, Cartier Tank, Audemars Piguet Royal Oak and Casio G-Shock. Submariner Date and Royal Oak show the local date; G-Shock shows local digital time, weekday and date. On Moonwatch, click the upper pusher to start, pause or resume the chronograph; the lower pusher stops and resets it. The same controls are in Interaction, including in dial-only mode. Running seconds are at 9, the 30-minute counter at 3, and the 12-hour counter at 6."), color: .secondaryLabelColor), to: content)
        addLink("Rolex Submariner ↗", url: URL(string: "https://www.rolex.com/watches/submariner/all-models")!, to: content)
        addLink("Omega Speedmaster Moonwatch ↗", url: URL(string: "https://www.omegawatches.com.hk/en-hk/watch-omega-speedmaster-moonwatch-professional-co-axial-master-chronometer-chronograph-42-mm-31030425001001")!, to: content)
        addLink("Cartier Tank Must ↗", url: URL(string: "https://www.cartier.com/en-us/tank.html")!, to: content)
        addLink("Audemars Piguet Royal Oak ↗", url: URL(string: "https://www.audemarspiguet.com/com/en/collections/royal-oak.html")!, to: content)
        add(label(L("G-Shock has Timekeeping, Alarm, Countdown and Stopwatch modes. A adjusts settings, records a split or resets; B starts/stops or increments; C changes mode or field; D illuminates the LCD. Hold B for two seconds in Timekeeping to toggle Flash Alert. Interaction offers the same controls and alarm/timer settings without the case.\n\nThe stopwatch supports split times and two finishes. The countdown runs from 1 second to 24 hours with optional auto-repeat. The alarm can be daily or limited by month/day; an hourly signal is also available. Settings are saved; elapsed timers last until the app is closed. Time follows macOS; A in Timekeeping selects only the 12/24-hour format, changed with D.\n\nSound requires the app to remain running. The app does not wake a sleeping Mac; overdue alarms are checked after wake, including when another theme is selected."), color: .secondaryLabelColor), to: content)
        addLink("Casio G-Shock DW-5600 ↗", url: URL(string: "https://www.casio.com/us/watches/gshock/product.DW-5600E-1V/")!, to: content)
        add(label(L("Pulsar P1 lights its red LED display for 1.25 seconds when its front button is pressed; keep holding to show seconds. Interaction offers time, seconds and display-off commands, also without the case."), color: .secondaryLabelColor), to: content)
        addLink("Hamilton Pulsar P1 · 1972 ↗", url: URL(string: "https://www.swatchgroup.com/en/services/archive/2020/hamilton-psr")!, to: content)
        section(L("Raketa"), identifier: "section-raketa")
        if let logo = NSImage(contentsOf: resources.appendingPathComponent("RaketaLogo.png")) {
            let image = NSImageView()
            image.image = logo
            image.imageScaling = .scaleProportionallyUpOrDown
            image.imageAlignment = .alignLeft
            image.setAccessibilityLabel(L("Red logo of the Raketa watch manufacturer"))
            add(image, to: content)
            image.heightAnchor.constraint(equalToConstant: 45).isActive = true
        }
        add(label(L("Watch manufacture · Peterhof"), size: 17, weight: .semibold), to: content)
        add(label(L("Raketa is a Russian watch manufacturer in Peterhof. According to its official website, the factory has more than 300 years of history. It makes Raketa and Pobeda watches and movement components, including the hairspring and balance wheel."), color: .secondaryLabelColor), to: content)
        addLink(L("Home page · raketa.com ↗"), url: URL(string: "https://raketa.com/")!, to: content)
        addLink(L("Official watch catalog ↗"), url: URL(string: "https://raketa.com/watches")!, to: content)
        add(label(L("Collection in the app · %ld models", raketaCount), size: 17, weight: .semibold), to: content)
        add(label(L("A fixed catalog snapshot from October 18, 2026. Dial photographs have been prepared to display the time; they are not production designs. The model list does not update automatically."), color: .secondaryLabelColor), to: content)
        if let image = NSImage(contentsOf: resources.appendingPathComponent("collection.png")), image.size.width > 0 {
            let gallery = NSImageView()
            gallery.image = image
            gallery.imageScaling = .scaleProportionallyUpOrDown
            gallery.allowsCutCopyPaste = true
            gallery.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            gallery.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            gallery.setAccessibilityLabel(L("All %ld Raketa models: dials, cases, and straps", raketaCount))
            add(gallery, to: content)
            gallery.heightAnchor.constraint(equalTo: gallery.widthAnchor, multiplier: image.size.height / image.size.width).isActive = true
        }
        section(L("Licenses and sources"), identifier: "section-licenses")
        add(label(L("The original code, Minimalism theme geometry, and menu bar icon are MIT licensed. The БОЛТ42 logo, app icon, and manufacturer graphics have a separate rights status; sources and restrictions are listed below and in the third-party notices.\n\nThe app works locally, without analytics, an account, or background network requests."), color: .secondaryLabelColor), to: content)
        addLink(L("MIT License · full text"), url: resources.appendingPathComponent("Legal/LICENSE"), to: content)
        addLink(L("License scope"), url: resources.appendingPathComponent("Legal/LICENSE_SCOPE.md"), to: content)
        addLink(L("Third-party materials and dependency licenses"), url: resources.appendingPathComponent("Legal/THIRD_PARTY_NOTICES.md"), to: content)
        add(label(L("Photographs, model information, names, and the red logo come from the manufacturer. Their rights belong to the respective rights holders. These materials, restored dials, hands, cases, straps, and the collection image are excluded from the MIT license. Permission for their further redistribution is not included in this project.\n\nA link to the official website identifies the source; it is not a license. This project does not claim the manufacturer’s endorsement."), color: .secondaryLabelColor), to: content)
        addLink("resvg-js · MPL 2.0 ↗", url: URL(string: "https://github.com/thx/resvg-js/blob/main/LICENSE")!, to: content)
        addLink("pngjs · MIT ↗", url: URL(string: "https://github.com/pngjs/pngjs/blob/main/LICENSE")!, to: content)
        section(L("Development"), identifier: "section-developer")
        if let logo = NSImage(contentsOf: resources.appendingPathComponent("DeveloperLogo.png")) {
            let panel = DeveloperLogoPanel(image: logo)
            panel.identifier = NSUserInterfaceItemIdentifier("developer-logo")
            add(panel, to: content)
            panel.heightAnchor.constraint(equalToConstant: 164).isActive = true
        }
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func label(_ text: String, size: CGFloat = 13, weight: NSFont.Weight = .regular,
                       color: NSColor = .labelColor) -> NSTextField {
        let view = NSTextField(wrappingLabelWithString: text)
        view.font = .systemFont(ofSize: size, weight: weight)
        view.textColor = color
        view.isSelectable = true
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .vertical)
        return view
    }

    private func makeHeader(resources: URL, version: String) -> NSView {
        let icon = NSImageView()
        icon.identifier = NSUserInterfaceItemIdentifier("app-icon")
        icon.image = NSImage(contentsOf: resources.appendingPathComponent("app.png"))
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.setAccessibilityLabel(L("Vremya app icon"))
        icon.widthAnchor.constraint(equalToConstant: 100).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 100).isActive = true
        let title = label(L("Vremya"), size: 32, weight: .semibold)
        let subtitle = label(L("Desktop clock for macOS · Version %@", version), color: .secondaryLabelColor)
        let text = NSStackView(views: [title, subtitle])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 7
        title.widthAnchor.constraint(equalTo: text.widthAnchor).isActive = true
        subtitle.widthAnchor.constraint(equalTo: text.widthAnchor).isActive = true
        let header = NSStackView(views: [icon, text])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 20
        return header
    }

    private func section(_ title: String, identifier: String) {
        let divider = NSBox()
        divider.boxType = .separator
        add(divider, to: contentStack)
        let heading = label(title, size: 18, weight: .semibold)
        heading.identifier = NSUserInterfaceItemIdentifier(identifier)
        add(heading, to: contentStack)
    }

    private func configureContent() {
        let scroll = scrollView
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        let document = AboutDocumentView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        let stack = contentStack
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        NSLayoutConstraint.activate([
            document.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            document.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -24),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -24)
        ])
    }

    private func add(_ view: NSView, to stack: NSStackView) {
        stack.addArrangedSubview(view)
        view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    private func addLink(_ title: String, url: URL, to stack: NSStackView) {
        let button = NSButton(title: title, target: self, action: #selector(openLink(_:)))
        button.isBordered = false
        button.alignment = .left
        button.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ])
        button.toolTip = url.isFileURL ? url.lastPathComponent : url.absoluteString
        button.setAccessibilityHelp(url.isFileURL ? L("Open local license text") : L("Open link in browser"))
        linkURLs[ObjectIdentifier(button)] = url
        add(button, to: stack)
    }

    @objc private func openLink(_ sender: NSButton) {
        guard let url = linkURLs[ObjectIdentifier(sender)] else { return }
        NSWorkspace.shared.open(url)
    }
}

@MainActor
private final class DeveloperLogoPanel: NSView {
    init(image: NSImage) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(srgbRed: 0.99, green: 0.98, blue: 0.95, alpha: 1).cgColor
        layer?.cornerRadius = 12
        let logo = NSImageView()
        logo.image = image
        logo.imageScaling = .scaleProportionallyUpOrDown
        logo.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        logo.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        logo.setContentHuggingPriority(.defaultLow, for: .horizontal)
        logo.setContentHuggingPriority(.defaultLow, for: .vertical)
        logo.setAccessibilityLabel(L("БОЛТ42 · Problem solving"))
        logo.translatesAutoresizingMaskIntoConstraints = false
        addSubview(logo)
        NSLayoutConstraint.activate([
            logo.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            logo.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            logo.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            logo.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
