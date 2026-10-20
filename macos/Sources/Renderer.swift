import AppKit
import ImageIO

enum DialError: Error, CustomStringConvertible {
    case resource(String)
    var description: String {
        switch self { case .resource(let name): return L("Could not read resource: %@", name) }
    }
}

final class DialRenderer {
    struct Layer {
        let spec: DialSpecification.Layer
        let image: CGImage
        let glyphs: [Character: CGImage]
    }
    let specification: DialSpecification
    let theme: ClockTheme
    let layers: [Layer]
    let hasSeconds: Bool
    let hasChronograph: Bool
    var isGShock: Bool { theme.id == "casio-gshock" }
    var isChronostop: Bool { specification.interactionProfile == "chronostop" }
    var isParking: Bool { specification.interactionProfile == "parking" }
    var isNavitimer: Bool { specification.interactionProfile == "navitimer" }
    var isPulsar: Bool { specification.interactionProfile == "pulsar" }
    var hasBezel: Bool { layers.contains { $0.spec.image.hasSuffix("/bezel.png") } }
    enum DrawingPass: Equatable { case all, background, live, foreground }
    private let firstLive: Int
    private let lastLive: Int

    init(resources: URL, theme: ClockTheme) throws {
        self.theme = theme
        let source = resources.appendingPathComponent(theme.specification)
        specification = try JSONDecoder().decode(DialSpecification.self,
            from: Data(contentsOf: source))
        try specification.validate()
        layers = try specification.layers.map { spec in
            let name = URL(fileURLWithPath: spec.image).lastPathComponent
            let url = source.deletingLastPathComponent().appendingPathComponent(name)
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw DialError.resource(name)
            }
            var glyphs: [Character: CGImage] = [:]
            if spec.type == "Text Res", let characters = spec.characters {
                guard image.width % characters.count == 0 else { throw DialError.resource(name) }
                let width = image.width / characters.count
                for (index, character) in characters.enumerated() {
                    guard let glyph = image.cropping(to: CGRect(x: index * width, y: 0, width: width, height: image.height)) else {
                        throw DialError.resource(name)
                    }
                    glyphs[character] = glyph
                }
            }
            return Layer(spec: spec, image: image, glyphs: glyphs)
        }
        let loadedLayers = layers
        let dynamic = loadedLayers.indices.filter { loadedLayers[$0].spec.type != "Single Res" }
        // Validation guarantees at least one contiguous group of live hand/text layers.
        firstLive = dynamic[0]
        lastLive = dynamic[dynamic.count - 1]
        hasSeconds = layers.contains { $0.spec.image.hasSuffix("/second.png") }
        hasChronograph = Set(loadedLayers.filter { $0.spec.type == "Hand Res" }.map {
            URL(fileURLWithPath: $0.spec.image).deletingPathExtension().lastPathComponent
        }).isSuperset(of: ["chrono-second", "chrono-minute", "chrono-hour"])
    }

    // Both AppKit and offscreen bitmap contexts enter with a bottom-left origin.
    // The authoring specification uses top-left coordinates and clockwise angles.
    func displaySize(width: CGFloat, showBezel: Bool) -> CGSize {
        let viewport = !showBezel ? specification.dialBounds : nil
        let ratio = (viewport?[3] ?? specification.resolution[1]) / (viewport?[2] ?? specification.resolution[0])
        return CGSize(width: width, height: (width * ratio).rounded())
    }

    func draw(in context: CGContext, size: CGSize, angles: HandAngles, showSeconds: Bool = true,
              showBezel: Bool = true, pass: DrawingPass = .all, chronograph: ChronographReading = ChronographReading(),
              gshock: GShockDisplay? = nil, pulsar: PulsarReading? = nil, heritage: HeritageReading = HeritageReading()) {
        context.saveGState()
        context.translateBy(x: 0, y: size.height)
        let viewport = !showBezel ? specification.dialBounds : nil
        context.scaleBy(x: size.width / (viewport?[2] ?? specification.resolution[0]), y: -size.height / (viewport?[3] ?? specification.resolution[1]))
        if let viewport { context.translateBy(x: -viewport[0], y: -viewport[1]) }
        context.interpolationQuality = .high
        for (index, layer) in layers.enumerated() {
            switch pass {
            case .all: break
            case .background: if index >= firstLive { continue }
            case .live: if index < firstLive || index > lastLive { continue }
            case .foreground: if index <= lastLive { continue }
            }
            let spec = layer.spec
            if let visibility = spec.visibility, visibility.hasPrefix("led-") {
                let mode = pulsar?.mode ?? .time
                if mode == .off || (visibility == "led-seconds") != (mode == .seconds) { continue }
            }
            if index == firstLive && isGShock && gshock?.backlit == true,
               let origin = layers.first(where: { $0.spec.image.hasSuffix("/lcd-marks.png") })?.spec.position {
                context.saveGState()
                context.addPath(CGPath(roundedRect: CGRect(x: origin[0], y: origin[1], width: 270, height: 170),
                                       cornerWidth: 8, cornerHeight: 8, transform: nil))
                context.clip()
                let colors = [CGColor(red: 0.30, green: 1, blue: 0.77, alpha: 0.7),
                              CGColor(red: 0.03, green: 0.73, blue: 0.65, alpha: 0.65)]
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1]) {
                    context.drawLinearGradient(gradient, start: CGPoint(x: origin[0], y: origin[1]),
                        end: CGPoint(x: origin[0], y: origin[1] + 170), options: [])
                }
                context.restoreGState()
            }
            if !showBezel && spec.image.hasSuffix("bezel.png") { continue }
            if !showSeconds && spec.image.hasSuffix("/second.png") { continue }
            drawLayer(layer, in: context, angles: angles, chronograph: chronograph, gshock: gshock, heritage: heritage)
        }
        context.restoreGState()
    }

    private func drawLayer(_ layer: Layer, in context: CGContext, angles: HandAngles,
                   chronograph: ChronographReading = ChronographReading(), gshock: GShockDisplay? = nil, heritage: HeritageReading = HeritageReading()) {
        let spec = layer.spec
        context.saveGState()
        let size = spec.size ?? specification.resolution
        if spec.type == "Text Res", let field = spec.field, let position = spec.position {
            let text = Array((isGShock ? gshock?.fields[field] : nil) ?? angles.text(for: field))
            let width = size[0] / Double(text.count)
            for (offset, character) in text.enumerated() {
                guard let glyph = layer.glyphs[character] else { continue }
                context.saveGState()
                context.translateBy(x: position[0] + Double(offset) * width, y: position[1] + size[1])
                context.scaleBy(x: 1, y: -1)
                context.draw(glyph, in: CGRect(x: 0, y: 0, width: width, height: size[1]))
                context.restoreGState()
            }
            context.restoreGState()
            return
        }
        if let center = spec.handResPosition, let pivot = spec.rotatePoint {
            context.translateBy(x: center[0], y: center[1])
            let name = URL(fileURLWithPath: spec.image).deletingPathExtension().lastPathComponent
            let angle = name == "alarm-disc" ? heritage.parkingAngle : name == "slide-rule" ? heritage.slideRuleAngle :
                name == "chrono-second" && isChronostop ? heritage.chronostop.angle(for: spec.image) :
                name.hasPrefix("chrono-") ? chronograph.angle(for: spec.image) : angles.angle(for: spec.image)
            context.rotate(by: angle * .pi / 180)
            context.translateBy(x: -pivot[0], y: -pivot[1])
        } else if let position = spec.position {
            context.translateBy(x: position[0], y: position[1])
        }
        // Preserve PNG orientation inside the flipped authoring canvas.
        context.translateBy(x: 0, y: size[1])
        context.scaleBy(x: 1, y: -1)
        context.draw(layer.image, in: CGRect(x: 0, y: 0, width: size[0], height: size[1]))
        context.restoreGState()
    }

    func png(side: Int, angles: HandAngles, showBezel: Bool = true, gshock: GShockDisplay? = nil,
             pulsar: PulsarReading? = nil) throws -> Data {
        let size = displaySize(width: CGFloat(side), showBezel: showBezel)
        guard let context = CGContext(data: nil, width: side, height: Int(size.height), bitsPerComponent: 8,
                bytesPerRow: side * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw DialError.resource("bitmap context")
        }
        draw(in: context, size: size, angles: angles, showBezel: showBezel, gshock: gshock, pulsar: pulsar)
        guard let image = context.makeImage() else { throw DialError.resource("render") }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil) else {
            throw DialError.resource("PNG writer")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw DialError.resource("PNG export") }
        return output as Data
    }
}

final class ThemeLibrary {
    let catalog: ThemeCatalog
    let resources: URL
    private var cached: DialRenderer?

    init(resources: URL) throws {
        self.resources = resources
        catalog = try JSONDecoder().decode(ThemeCatalog.self,
            from: Data(contentsOf: resources.appendingPathComponent("themes.json")))
        try catalog.validate()
    }

    func renderer(for id: String?) throws -> DialRenderer {
        guard let theme = catalog.theme(for: id) else { throw DialError.resource("default theme") }
        if let cached, cached.theme.id == theme.id { return cached }
        let renderer = try DialRenderer(resources: resources, theme: theme)
        cached = renderer
        return renderer
    }
}
