import Foundation
import CoreGraphics

func close(_ actual: Double, _ expected: Double, _ message: String) {
    precondition(abs(actual - expected) < 0.00001, "\(message): \(actual) ≠ \(expected)")
}
let reference = HandAngles(hours: 20, minutes: 10, seconds: 24)
close(reference.hour, 302.6, "24-hour reference hour")
close(reference.minute, 62.4, "reference minute")
close(reference.second, 144, "reference second")
close(HandAngles(hours: 12, minutes: 0, seconds: 0).hour, 180, "noon is at the bottom")
close(HandAngles(hours: 0, minutes: 0, seconds: 0).hour, 0, "midnight is at the top")
let fractional = HandAngles(hours: 23, minutes: 59, seconds: 59.5)
close(fractional.second, 357, "fractional seconds remain smooth")
close(fractional.hour, 359.9979166667, "hour hand approaches midnight continuously")
let instant = ISO8601DateFormatter().date(from: "2026-10-18T00:30:00Z")!
var moscow = Calendar(identifier: .gregorian)
moscow.timeZone = TimeZone(identifier: "Europe/Moscow")!
var newYork = Calendar(identifier: .gregorian)
newYork.timeZone = TimeZone(identifier: "America/New_York")!
close(HandAngles(date: instant, calendar: moscow).hour, 52.5, "local Moscow time")
close(HandAngles(date: instant, calendar: newYork).hour, 307.5, "previous local day in New York")
close(HandAngles(hours: 12, minutes: 0, seconds: 0, hourCycle: 12).hour, 0, "Avangard noon at top")
close(HandAngles(hours: 18, minutes: 0, seconds: 0, hourCycle: 12).hour, 180, "Avangard evening at bottom")
close(HandAngles(hours: 6, minutes: 7, seconds: 50, hourCycle: 12).hour, 183.9166666667, "Avangard hour progression")
let catalog = try! JSONDecoder().decode(ThemeCatalog.self, from: Data(contentsOf: URL(fileURLWithPath: "themes.json")))
precondition(catalog.theme(for: "minimalism")!.hourCycle == 12 && !catalog.theme(for: "minimalism")!.isRaketa)
precondition(catalog.theme(for: "minimalism-24")!.hourCycle == 24 && !catalog.theme(for: "minimalism-24")!.isRaketa)
precondition(catalog.theme(for: "minimalism-dark")!.id == "minimalism-dark" && catalog.theme(for: "minimalism-dark")!.hourCycle == 12)
precondition(catalog.theme(for: "minimalism-24-dark")!.id == "minimalism-24-dark" && catalog.theme(for: "minimalism-24-dark")!.hourCycle == 24)
precondition(catalog.theme(for: "avangard")!.hourCycle == 12)
precondition(catalog.theme(for: nil)!.id == catalog.defaultTheme)
precondition(catalog.theme(for: "removed-theme")!.id == catalog.defaultTheme)
precondition(catalog.defaultTheme == "minimalism-24-dark")
precondition(catalog.theme(for: "polar")!.id == catalog.defaultTheme, "Removed saved theme must migrate to default")
precondition(catalog.themes.filter(\.isRaketa).count == 21)
print("Passed: 12/24-hour cycles, reference pose, timezone conversion, theme selection and default fallback")
let reverse = HandAngles(hours: 1, minutes: 10, seconds: 20, hourCycle: 12, direction: -1)
close(reverse.hour, -35.1666666667, "Russian Code hour counterclockwise")
close(reverse.minute, -62, "Russian Code minute counterclockwise")
close(reverse.second, -120, "Russian Code seconds counterclockwise")
precondition(catalog.themes.count == 25)
precondition(catalog.theme(for: "russkiy-kod-0344")!.rotationDirection == -1)
precondition(catalog.theme(for: "raketa-avgvst")!.dialShape == "rectangle")
print("Passed: complete catalog, reverse movement and rectangular Avgvst metadata")

do { try catalog.validate() } catch {
    FileHandle.standardError.write(Data("Catalog validation failed: \(error)\n".utf8)); exit(1)
}
for theme in catalog.themes {
    let data = try Data(contentsOf: URL(fileURLWithPath: "assets/\(theme.specification)"))
    do { try JSONDecoder().decode(DialSpecification.self, from: data).validate() } catch {
        FileHandle.standardError.write(Data("Theme validation failed: \(theme.id): \(error)\n".utf8)); exit(1)
    }
}
func rejects(_ body: () throws -> Void, _ message: String) {
    do { try body(); preconditionFailure(message) } catch { }
}
for arguments in [["--render"], ["--render", "x.png", "--time", "12:x:30:00"],
                  ["--render", "x.png", "--time", "24:00:00"], ["--render", "x.png", "--size", "2049"],
                  ["--render", "x.png", "--size", "NaN"], ["--no-bezel"], ["--time", "12:00:00"],
                  ["--wat"], ["--theme", "minimalism", "--theme", "avangard"]] {
    rejects({ _ = try LaunchOptions(arguments: arguments) }, "Invalid CLI was accepted: \(arguments)")
}
let options = try LaunchOptions(arguments: ["--render", "output.png", "--theme", "minimalism", "--time", "23:59:59", "--size", "2048", "--no-bezel"])
precondition(options.time?.hours == 23 && options.time?.seconds == 59 && options.size == 2048 && !options.showBezel)
for value in ["../theme.json", "/theme.json", "a/../theme.json", "a//theme.json", "a\\theme.json"] {
    precondition(!isSafeResourcePath(value))
}
let malformedSpec = Data("""
{"resolution":[0,100],"layers":[]}
""".utf8)
rejects({ try JSONDecoder().decode(DialSpecification.self, from: malformedSpec).validate() }, "Zero-size canvas was accepted")
precondition(WindowGeometry.savedOrigin([.nan, 20]) == nil)
precondition(WindowGeometry.savedOrigin([20]) == nil)
let left = CGRect(x: -1440, y: 0, width: 1440, height: 900)
let right = CGRect(x: 0, y: 0, width: 1440, height: 900)
let fitted = WindowGeometry.fitted(CGRect(x: -2000, y: 800, width: 466, height: 1300), to: [left, right])
precondition(left.contains(fitted) && abs(fitted.height / fitted.width - 1300.0 / 466) < 0.001)
precondition(WindowGeometry.fitted(CGRect(x: 4000, y: 0, width: 280, height: 280), to: [left, right]).maxX == right.maxX)
close(AnimationPolicy.interval(smooth: true, showSeconds: true, hasSeconds: true, reduceMotion: false, lowPower: false), 1.0 / 30, "normal frame rate")
close(AnimationPolicy.interval(smooth: true, showSeconds: true, hasSeconds: true, reduceMotion: false, lowPower: true), 1.0 / 15, "low-power frame rate")
close(AnimationPolicy.interval(smooth: true, showSeconds: true, hasSeconds: true, reduceMotion: true, lowPower: false), 1, "Reduce Motion")
close(AnimationPolicy.interval(smooth: true, showSeconds: true, hasSeconds: false, reduceMotion: false, lowPower: false), 1, "two-hand theme")
print("Passed: theme validation, strict export CLI, safe resource paths, restored window geometry and animation policy")
