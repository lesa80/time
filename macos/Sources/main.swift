import AppKit

let arguments = Array(CommandLine.arguments.dropFirst())
do {
    let options = try LaunchOptions(arguments: arguments)
    if options.help {
        print(LaunchOptions.usage)
    } else {
        guard let resources = Bundle.main.resourceURL else { throw DialError.resource("bundle resources") }
        let library = try ThemeLibrary(resources: resources)
        if let id = options.themeID, !library.catalog.themes.contains(where: { $0.id == id }) {
            throw ModelError.invalid("неизвестная тема: \(id)")
        }
        if let output = options.output {
            let renderer = try library.renderer(for: options.themeID)
            let time = options.time ?? (20, 10, 24)
            let angles = HandAngles(hours: time.0, minutes: time.1, seconds: time.2,
                hourCycle: renderer.theme.hourCycle, direction: renderer.theme.rotationDirection)
            try renderer.png(side: options.size, angles: angles, showBezel: options.showBezel)
                .write(to: URL(fileURLWithPath: output), options: .atomic)
            let size = renderer.displaySize(width: CGFloat(options.size), showBezel: options.showBezel)
            print("Rendered \(options.size) × \(Int(size.height)): \(output)")
        } else {
            let app = NSApplication.shared
            let renderer = try library.renderer(for: options.themeID ?? UserDefaults.standard.string(forKey: "themeID"))
            let delegate = AppDelegate(library: library, renderer: renderer)
            app.setActivationPolicy(.accessory)
            app.delegate = delegate
            withExtendedLifetime(delegate) { app.run() }
        }
    }
} catch {
    let message = "Время: \(error)"
    FileHandle.standardError.write(Data((message + "\n").utf8))
    if arguments.isEmpty {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Не удалось открыть «Время»"
        alert.informativeText = "\(error)\n\nПереустановите приложение из полного архива."
        alert.runModal()
    }
    exit(1)
}
