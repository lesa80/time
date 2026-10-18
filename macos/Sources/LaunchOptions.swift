import Foundation

struct LaunchOptions {
    var output: String?
    var themeID: String?
    var time: (hours: Int, minutes: Int, seconds: Double)?
    var size = 466
    var showBezel = true
    var help = false

    static let usage = """
    Usage: Vremya [--theme ID]
           Vremya --render FILE [--theme ID] [--time HH:mm:ss] [--size 16...2048] [--no-bezel]
           Vremya --help
    """

    init(arguments: [String]) throws {
        var index = 0
        var seen = Set<String>()
        while index < arguments.count {
            let option = arguments[index]
            guard seen.insert(option).inserted else { throw ModelError.invalid(L("duplicate argument: %@", option)) }
            func value() throws -> String {
                guard index + 1 < arguments.count, !arguments[index + 1].hasPrefix("--"), !arguments[index + 1].isEmpty else {
                    throw ModelError.invalid(L("%@ requires a value", option))
                }
                index += 1
                return arguments[index]
            }
            switch option {
            case "--render": output = try value()
            case "--theme": themeID = try value()
            case "--time":
                let input = try value()
                let parts = input.split(separator: ":", omittingEmptySubsequences: false)
                guard parts.count == 3, parts.allSatisfy({ $0.count == 2 && $0.allSatisfy(\.isNumber) }),
                      let h = Int(parts[0]), let m = Int(parts[1]), let s = Int(parts[2]),
                      (0..<24).contains(h), (0..<60).contains(m), (0..<60).contains(s) else {
                    throw ModelError.invalid(L("--time: expected HH:mm:ss"))
                }
                time = (h, m, Double(s))
            case "--size":
                guard let number = Int(try value()), (16...2048).contains(number) else {
                    throw ModelError.invalid(L("--size: expected an integer from 16 to 2048"))
                }
                size = number
            case "--no-bezel": showBezel = false
            case "--help": help = true
            default: throw ModelError.invalid(L("unknown argument: %@", option))
            }
            index += 1
        }
        guard output != nil || (time == nil && !seen.contains("--size") && showBezel) else {
            throw ModelError.invalid(L("--time, --size and --no-bezel require --render"))
        }
    }
}
