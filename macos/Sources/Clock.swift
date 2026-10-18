import Foundation

enum ModelError: Error, CustomStringConvertible {
    case invalid(String)
    var description: String {
        switch self { case .invalid(let message): return "Некорректные данные: \(message)" }
    }
}

func isSafeResourcePath(_ value: String) -> Bool {
    !value.isEmpty && !value.hasPrefix("/") && !value.contains("\\") && !value.contains(":") &&
        value.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
}

struct HandAngles {
    let hour: Double
    let minute: Double
    let second: Double

    init(hours: Int, minutes: Int, seconds: Double, hourCycle: Int = 24, direction: Int = 1) {
        precondition(hourCycle == 12 || hourCycle == 24)
        precondition(direction == 1 || direction == -1)
        let preciseMinutes = Double(minutes) + seconds / 60
        hour = (Double(hours % hourCycle) + preciseMinutes / 60) * 360 / Double(hourCycle) * Double(direction)
        minute = preciseMinutes * 6 * Double(direction)
        second = seconds * 6 * Double(direction)
    }

    init(date: Date, calendar: Calendar = .current, hourCycle: Int = 24, direction: Int = 1) {
        let parts = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        self.init(hours: parts.hour!, minutes: parts.minute!,
                  seconds: Double(parts.second!) + Double(parts.nanosecond ?? 0) / 1e9, hourCycle: hourCycle, direction: direction)
    }

    func angle(for image: String) -> Double {
        switch URL(fileURLWithPath: image).deletingPathExtension().lastPathComponent {
        case "hour": return hour
        case "minute": return minute
        case "second": return second
        default: return 0
        }
    }
}

struct ClockTheme: Decodable {
    let id: String
    let title: String
    let hourCycle: Int
    let specification: String
    let direction: Int?
    let dialShape: String?
    let brand: String?
    var isRaketa: Bool { brand == "raketa" }
    var rotationDirection: Int { direction ?? 1 }
}

struct ThemeCatalog: Decodable {
    let defaultTheme: String
    let themes: [ClockTheme]

    func theme(for id: String?) -> ClockTheme? {
        themes.first(where: { $0.id == id }) ?? themes.first(where: { $0.id == defaultTheme })
    }

    func validate() throws {
        guard !themes.isEmpty, Set(themes.map(\.id)).count == themes.count,
              themes.contains(where: { $0.id == defaultTheme }),
              themes.allSatisfy({ !$0.id.isEmpty && !$0.title.isEmpty && [12, 24].contains($0.hourCycle) &&
                  [1, -1].contains($0.rotationDirection) && isSafeResourcePath($0.specification) &&
                  $0.specification.hasSuffix(".json") && [nil, "raketa"].contains($0.brand) &&
                  [nil, "circle", "rectangle"].contains($0.dialShape) }) else {
            throw ModelError.invalid("themes.json")
        }
    }
}

struct DialSpecification: Decodable {
    struct Layer: Decodable {
        let type: String
        let image: String
        let position: [Double]?
        let handResPosition: [Double]?
        let rotatePoint: [Double]?
        let size: [Double]?
    }
    let resolution: [Double]
    let dialBounds: [Double]?
    let dialShape: String?
    let layers: [Layer]

    func validate() throws {
        func point(_ vector: [Double]?) -> Bool {
            guard let vector else { return false }
            return vector.count == 2 && vector.allSatisfy(\.isFinite)
        }
        func size(_ vector: [Double]?) -> Bool {
            guard let vector else { return false }
            return point(vector) && vector.allSatisfy { $0 > 0 && $0 <= 16_384 }
        }
        guard size(resolution), [nil, "circle", "rectangle"].contains(dialShape), !layers.isEmpty else {
            throw ModelError.invalid("размер или форма циферблата")
        }
        if let bounds = dialBounds {
            guard bounds.count == 4, bounds.allSatisfy(\.isFinite), bounds[0] >= 0, bounds[1] >= 0,
                  bounds[2] > 0, bounds[3] > 0, bounds[0] + bounds[2] <= resolution[0] + 0.01,
                  bounds[1] + bounds[3] <= resolution[1] + 0.01 else {
                throw ModelError.invalid("границы циферблата")
            }
        }
        var handNames = Set<String>()
        var hasSeenHand = false, hasSeenForeground = false
        for layer in layers {
            guard isSafeResourcePath(layer.image), layer.image.hasSuffix(".png"), size(layer.size ?? resolution) else {
                throw ModelError.invalid("ресурс слоя \(layer.image)")
            }
            if layer.type == "Hand Res" {
                let name = URL(fileURLWithPath: layer.image).deletingPathExtension().lastPathComponent
                guard !hasSeenForeground, ["hour", "minute", "second"].contains(name), handNames.insert(name).inserted,
                      point(layer.handResPosition), point(layer.rotatePoint), layer.position == nil else {
                    throw ModelError.invalid("геометрия стрелки \(layer.image)")
                }
                hasSeenHand = true
            } else {
                guard layer.type == "Single Res", point(layer.position), layer.handResPosition == nil, layer.rotatePoint == nil else {
                    throw ModelError.invalid("неподвижный слой \(layer.image)")
                }
                if hasSeenHand { hasSeenForeground = true }
            }
        }
        guard handNames.isSuperset(of: ["hour", "minute"]) else { throw ModelError.invalid("отсутствуют стрелки") }
    }
}
