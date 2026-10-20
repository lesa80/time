import Foundation

enum ModelError: Error, CustomStringConvertible {
    case invalid(String)
    var description: String {
        switch self { case .invalid(let message): return L("Invalid data: %@", message) }
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
    let hours: Int
    let minutes: Int
    let seconds: Int
    let day: Int
    let month: Int
    let weekday: Int

    init(hours: Int, minutes: Int, seconds: Double, hourCycle: Int = 24, direction: Int = 1,
         day: Int = 1, month: Int = 1, weekday: Int = 1) {
        precondition(hourCycle == 12 || hourCycle == 24)
        precondition(direction == 1 || direction == -1)
        let preciseMinutes = Double(minutes) + seconds / 60
        hour = (Double(hours % hourCycle) + preciseMinutes / 60) * 360 / Double(hourCycle) * Double(direction)
        minute = preciseMinutes * 6 * Double(direction)
        second = seconds * 6 * Double(direction)
        self.hours = hours; self.minutes = minutes; self.seconds = Int(seconds)
        self.day = day; self.month = month; self.weekday = weekday
    }

    init(date: Date, calendar: Calendar = .current, hourCycle: Int = 24, direction: Int = 1) {
        let parts = calendar.dateComponents([.hour, .minute, .second, .nanosecond, .day, .month, .weekday], from: date)
        self.init(hours: parts.hour!, minutes: parts.minute!,
                  seconds: Double(parts.second!) + Double(parts.nanosecond ?? 0) / 1e9, hourCycle: hourCycle, direction: direction,
                  day: parts.day!, month: parts.month!, weekday: parts.weekday!)
    }

    func text(for field: String) -> String {
        func two(_ value: Int) -> String { value < 10 ? "0\(value)" : String(value) }
        switch field {
        case "hours": return two(hours)
        case "hours12": return String(format: "%2d", hours % 12 == 0 ? 12 : hours % 12)
        case "colon": return ":"
        case "minutes": return two(minutes)
        case "seconds": return two(seconds)
        case "day": return two(day)
        case "month": return two(month)
        case "date": return day < 10 ? " \(day)" : String(day)
        case "weekday": return ["SU", "MO", "TU", "WE", "TH", "FR", "SA"][weekday - 1]
        case "format": return "24H"
        case "indicators": return String(repeating: " ", count: 13)
        case "separator": return "-"
        default: return "  "
        }
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
    var isIcon: Bool { brand == "icons" }
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
                  $0.specification.hasSuffix(".json") && [nil, "raketa", "icons"].contains($0.brand) &&
                  [nil, "circle", "rectangle"].contains($0.dialShape) }) else {
            throw ModelError.invalid("themes.json")
        }
    }
}

struct DialSpecification: Decodable {
    enum MechanicalAction: String, Decodable {
        case chronographToggle = "chronograph-toggle"
        case chronographReset = "chronograph-reset"
        case gshockA = "gshock-a"
        case gshockB = "gshock-b"
        case gshockC = "gshock-c"
        case gshockD = "gshock-d"
        case gshockFlash = "gshock-flash"
        case pulsarLight = "pulsar-light"
        case pulsarSeconds = "pulsar-seconds"
        case pulsarPress = "pulsar-press"
        case pulsarRelease = "pulsar-release"
        case pulsarCancel = "pulsar-cancel"
        case chronostop = "chronostop"
        case chronostopPress = "chronostop-press"
        case chronostopRelease = "chronostop-release"
        case parkingCrown = "parking-crown"
    }
    struct MechanicalControl: Decodable {
        let action: MechanicalAction
        /// Top-left authoring coordinates, matching the visible pusher on the case.
        let bounds: [Double]
        let longAction: MechanicalAction?
    }
    struct Layer: Decodable {
        let type: String
        let image: String
        let position: [Double]?
        let handResPosition: [Double]?
        let rotatePoint: [Double]?
        let size: [Double]?
        let field: String?
        let characters: String?
        let visibility: String?
    }
    let resolution: [Double]
    let dialBounds: [Double]?
    let dialShape: String?
    let layers: [Layer]
    let displayMode: String?
    let mechanicalControls: [MechanicalControl]?
    let interactionProfile: String?

    func validate() throws {
        func point(_ vector: [Double]?) -> Bool {
            guard let vector else { return false }
            return vector.count == 2 && vector.allSatisfy(\.isFinite)
        }
        func size(_ vector: [Double]?) -> Bool {
            guard let vector else { return false }
            return point(vector) && vector.allSatisfy { $0 > 0 && $0 <= 16_384 }
        }
        guard size(resolution), [nil, "circle", "rectangle"].contains(dialShape),
              [nil, "analog", "digital"].contains(displayMode),
              [nil, "pulsar", "chronostop", "parking", "navitimer"].contains(interactionProfile), !layers.isEmpty else {
            throw ModelError.invalid(L("dial size or shape"))
        }
        if let bounds = dialBounds {
            guard bounds.count == 4, bounds.allSatisfy(\.isFinite), bounds[0] >= 0, bounds[1] >= 0,
                  bounds[2] > 0, bounds[3] > 0, bounds[0] + bounds[2] <= resolution[0] + 0.01,
                  bounds[1] + bounds[3] <= resolution[1] + 0.01 else {
                throw ModelError.invalid(L("dial bounds"))
            }
        }
        var handNames = Set<String>()
        var hasSeenHand = false, hasSeenForeground = false
        for layer in layers {
            if let visibility = layer.visibility {
                guard (interactionProfile == "pulsar" && ["led-time", "led-seconds"].contains(visibility) && layer.type == "Text Res") else {
                    throw ModelError.invalid(L("layer resource: %@", layer.image))
                }
            }
            guard isSafeResourcePath(layer.image), layer.image.hasSuffix(".png"), size(layer.size ?? resolution) else {
                throw ModelError.invalid(L("layer resource: %@", layer.image))
            }
            if layer.type == "Text Res" {
                guard !hasSeenForeground, point(layer.position), layer.handResPosition == nil,
                      layer.rotatePoint == nil, let field = layer.field,
                      ["hours", "hours12", "colon", "minutes", "seconds", "day", "month", "weekday", "date", "format", "indicators", "separator"].contains(field),
                      let characters = layer.characters, !characters.isEmpty, characters.count <= 64,
                      Set(characters).count == characters.count,
                      Set("0123456789 SUMOTWEHFR A").isSubset(of: Set(characters)) else {
                    throw ModelError.invalid(L("text layer geometry: %@", layer.image))
                }
                hasSeenHand = true
            } else if layer.type == "Hand Res" {
                let name = URL(fileURLWithPath: layer.image).deletingPathExtension().lastPathComponent
                guard !hasSeenForeground, ["hour", "minute", "second", "chrono-second", "chrono-minute", "chrono-hour", "alarm-disc", "slide-rule"].contains(name), handNames.insert(name).inserted,
                      point(layer.handResPosition), point(layer.rotatePoint), layer.position == nil else {
                    throw ModelError.invalid(L("hand geometry: %@", layer.image))
                }
                hasSeenHand = true
            } else {
                guard layer.type == "Single Res", point(layer.position), layer.handResPosition == nil, layer.rotatePoint == nil else {
                    throw ModelError.invalid(L("static layer: %@", layer.image))
                }
                if hasSeenHand { hasSeenForeground = true }
            }
        }
        if displayMode == "digital" {
            let required: Set<String> = interactionProfile == "pulsar" ? ["hours12", "colon", "minutes", "seconds"] : ["hours", "minutes", "seconds"]
            guard handNames.isEmpty,
                  Set(layers.filter { $0.type == "Text Res" }.compactMap(\.field)).isSuperset(of: required) else {
                throw ModelError.invalid(L("missing digital fields"))
            }
        } else {
            guard handNames.isSuperset(of: ["hour", "minute"]) else { throw ModelError.invalid(L("missing hands")) }
        }
        let chronographHands: Set<String> = ["chrono-second", "chrono-minute", "chrono-hour"]
        guard (interactionProfile == "chronostop" && handNames.intersection(chronographHands) == ["chrono-second"]) ||
            handNames.isDisjoint(with: chronographHands) || handNames.isSuperset(of: chronographHands) else {
            throw ModelError.invalid(L("missing hands"))
        }
        if let controls = mechanicalControls {
            let actions = Set(controls.map(\.action))
            let analogActions: Set<MechanicalAction> = [.chronographToggle, .chronographReset]
            let digitalActions: Set<MechanicalAction> = [.gshockA, .gshockB, .gshockC, .gshockD]
            let validActions = interactionProfile == "chronostop" ? actions == [.chronostop] :
                interactionProfile == "parking" ? actions == [.parkingCrown] :
                interactionProfile == "pulsar" ? actions == [.pulsarLight] :
                displayMode == "digital" ? actions == digitalActions :
                handNames.isSuperset(of: chronographHands) && actions.isSubset(of: analogActions)
            guard Set(controls.map(\.action)).count == controls.count, validActions,
                  controls.allSatisfy({ $0.longAction == nil || ($0.action == .gshockB && $0.longAction == .gshockFlash) ||
                    (interactionProfile == "pulsar" && $0.action == .pulsarLight && $0.longAction == .pulsarSeconds) }),
                  controls.allSatisfy({ control in
                      let b = control.bounds
                      return b.count == 4 && b.allSatisfy(\.isFinite) && b[0] >= 0 && b[1] >= 0 &&
                          b[2] > 0 && b[3] > 0 && b[0] + b[2] <= resolution[0] && b[1] + b[3] <= resolution[1]
                  }) else { throw ModelError.invalid(L("dial bounds")) }
        }
    }
}
