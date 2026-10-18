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
    }
    let specification: DialSpecification
    let theme: ClockTheme
    let layers: [Layer]
    let hasSeconds: Bool
    var hasBezel: Bool { layers.contains { $0.spec.image.hasSuffix("/bezel.png") } }
    enum DrawingPass { case all, background, hands, foreground }
    private let firstHand: Int
    private let lastHand: Int

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
            return Layer(spec: spec, image: image)
        }
        let loadedLayers = layers
        let hands = loadedLayers.indices.filter { loadedLayers[$0].spec.type == "Hand Res" }
        // validate() guarantees both hour and minute and contiguous hand layers.
        firstHand = hands[0]
        lastHand = hands[hands.count - 1]
        hasSeconds = layers.contains { $0.spec.image.hasSuffix("/second.png") }
    }

    // Both AppKit and offscreen bitmap contexts enter with a bottom-left origin.
    // The authoring specification uses top-left coordinates and clockwise angles.
    func displaySize(width: CGFloat, showBezel: Bool) -> CGSize {
        let viewport = !showBezel ? specification.dialBounds : nil
        let ratio = (viewport?[3] ?? specification.resolution[1]) / (viewport?[2] ?? specification.resolution[0])
        return CGSize(width: width, height: (width * ratio).rounded())
    }

    func draw(in context: CGContext, size: CGSize, angles: HandAngles, showSeconds: Bool = true,
              showBezel: Bool = true, pass: DrawingPass = .all) {
        context.saveGState()
        context.translateBy(x: 0, y: size.height)
        let viewport = !showBezel ? specification.dialBounds : nil
        context.scaleBy(x: size.width / (viewport?[2] ?? specification.resolution[0]), y: -size.height / (viewport?[3] ?? specification.resolution[1]))
        if let viewport { context.translateBy(x: -viewport[0], y: -viewport[1]) }
        context.interpolationQuality = .high
        for (index, layer) in layers.enumerated() {
            switch pass {
            case .all: break
            case .background: if index >= firstHand { continue }
            case .hands: if index < firstHand || index > lastHand { continue }
            case .foreground: if index <= lastHand { continue }
            }
            let spec = layer.spec
            if !showBezel && spec.image.hasSuffix("bezel.png") { continue }
            if !showSeconds && spec.image.hasSuffix("second.png") { continue }
            context.saveGState()
            let size = spec.size ?? specification.resolution
            if let center = spec.handResPosition, let pivot = spec.rotatePoint {
                context.translateBy(x: center[0], y: center[1])
                context.rotate(by: angles.angle(for: spec.image) * .pi / 180)
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
        context.restoreGState()
    }

    func png(side: Int, angles: HandAngles, showBezel: Bool = true) throws -> Data {
        let size = displaySize(width: CGFloat(side), showBezel: showBezel)
        guard let context = CGContext(data: nil, width: side, height: Int(size.height), bitsPerComponent: 8,
                bytesPerRow: side * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw DialError.resource("bitmap context")
        }
        draw(in: context, size: size, angles: angles, showBezel: showBezel)
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
