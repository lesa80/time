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
        window.title = "О часах"
        window.minSize = NSSize(width: 640, height: 480)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.contentView = scrollView
        configureContent()
        let content = contentStack
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.4.4"
        add(makeHeader(resources: resources, version: version), to: content)
        add(label("Независимое неофициальное приложение. Проект не связан с часовой мануфактурой «Ракета» и не представляет её."), to: content)
        section("Краткая справка", identifier: "section-help")
        add(label("Доступно тем: \(themeCount). Местное время macOS. «Минимализм» и «Минимализм 24» — собственные темы приложения с 12- и 24-часовой шкалами, в светлом и тёмном вариантах. Тема по умолчанию — «Минимализм 24 — тёмный»; ранее сохранённый выбор имеет приоритет. Темы производителя собраны в меню «Тема → Ракета»; их шкала и направление стрелок соответствуют выбранной модели.\n\nПеретаскивайте часы, чтобы переместить их. Клик по часам переключает циферблат и вид с безелем и ремешком. У всех вариантов «Минимализма» собственный корпус с матовым ремешком.\n\nЛевый клик по значку часов в строке меню — «Поверх окон»; точка рядом со значком означает, что режим включён. Правый клик или Control-клик по значку или виджету открывает настройки: тема, размер, закрепление, секундная стрелка и автозапуск.\n\nАвтозапуск работает после входа в учётную запись. Для него переместите приложение в «Программы». Если macOS запросит разрешение, откройте «Основные → Объекты входа»."), to: content)
        section("Ракета", identifier: "section-raketa")
        if let logo = NSImage(contentsOf: resources.appendingPathComponent("RaketaLogo.png")) {
            let image = NSImageView()
            image.image = logo
            image.imageScaling = .scaleProportionallyUpOrDown
            image.imageAlignment = .alignLeft
            image.setAccessibilityLabel("Красный логотип часовой мануфактуры Ракета")
            add(image, to: content)
            image.heightAnchor.constraint(equalToConstant: 45).isActive = true
        }
        add(label("Часовая мануфактура · Петергоф", size: 17, weight: .semibold), to: content)
        add(label("«Ракета» — российская часовая мануфактура в Петергофе. По материалам официального сайта, история завода насчитывает более 300 лет; он выпускает часы «Ракета» и «Победа» и производит детали часовых механизмов, включая спираль и баланс.", color: .secondaryLabelColor), to: content)
        addLink("Главная страница · raketa.com ↗", url: URL(string: "https://raketa.com/")!, to: content)
        addLink("Официальный каталог часов ↗", url: URL(string: "https://raketa.com/watches")!, to: content)
        add(label("Коллекция в приложении · \(raketaCount) модель", size: 17, weight: .semibold), to: content)
        add(label("Фиксированный снимок каталога от 18 октября 2026 года. Фотографии циферблатов подготовлены для отображения времени; это не производственные макеты. Список моделей не обновляется автоматически.", color: .secondaryLabelColor), to: content)
        if let image = NSImage(contentsOf: resources.appendingPathComponent("collection.png")), image.size.width > 0 {
            let gallery = NSImageView()
            gallery.image = image
            gallery.imageScaling = .scaleProportionallyUpOrDown
            gallery.allowsCutCopyPaste = true
            gallery.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            gallery.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            gallery.setAccessibilityLabel("Все \(raketaCount) модели Ракета: циферблаты, корпуса и ремешки")
            add(gallery, to: content)
            gallery.heightAnchor.constraint(equalTo: gallery.widthAnchor, multiplier: image.size.height / image.size.width).isActive = true
        }
        section("Лицензии и источники", identifier: "section-licenses")
        add(label("Оригинальный код, геометрия тем «Минимализм» и значок строки меню — MIT. Логотип БОЛТ42, иконка приложения и графика производителя имеют отдельный статус; источники и ограничения приведены ниже и в уведомлениях о сторонних материалах.\n\nПриложение работает локально, без аналитики, учётной записи и фоновых сетевых запросов.", color: .secondaryLabelColor), to: content)
        addLink("MIT License · полный текст", url: resources.appendingPathComponent("Legal/LICENSE"), to: content)
        addLink("Область действия лицензии", url: resources.appendingPathComponent("Legal/LICENSE_SCOPE.md"), to: content)
        addLink("Сторонние материалы и лицензии зависимостей", url: resources.appendingPathComponent("Legal/THIRD_PARTY_NOTICES.md"), to: content)
        add(label("Фотографии, сведения о моделях, названия и красный логотип взяты из материалов производителя. Права на них принадлежат соответствующим правообладателям. Эти материалы, восстановленные циферблаты, стрелки, корпуса, ремешки и коллаж исключены из MIT. Разрешение на их дальнейшее распространение в проект не включено.\n\nСсылка на официальный сайт является указанием источника, а не лицензией. Проект не заявляет об одобрении со стороны производителя.", color: .secondaryLabelColor), to: content)
        addLink("resvg-js · MPL 2.0 ↗", url: URL(string: "https://github.com/thx/resvg-js/blob/main/LICENSE")!, to: content)
        addLink("pngjs · MIT ↗", url: URL(string: "https://github.com/pngjs/pngjs/blob/main/LICENSE")!, to: content)
        section("Разработка", identifier: "section-developer")
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
        icon.setAccessibilityLabel("Иконка приложения Время")
        icon.widthAnchor.constraint(equalToConstant: 100).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 100).isActive = true
        let title = label("Время", size: 32, weight: .semibold)
        let subtitle = label("Часы для рабочего стола macOS · Версия \(version)", color: .secondaryLabelColor)
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
        button.setAccessibilityHelp(url.isFileURL ? "Открыть локальный текст лицензии" : "Открыть ссылку в браузере")
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
        logo.setAccessibilityLabel("БОЛТ42 · Решение проблем")
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
