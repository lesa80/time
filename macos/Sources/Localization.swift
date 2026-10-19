import Foundation

/// Uses the primary macOS/app language; unsupported languages fall back to English.
/// An English source string is also a readable fallback if a resource is missing.
struct Localization: Sendable {
    static let supportedLanguages = ["ru", "en", "de", "fr", "es"]
    static let current = Localization()

    let language: String
    private let translations: [String: String]

    static func language(for preferredLanguages: [String]) -> String {
        guard let primary = preferredLanguages.first else { return "en" }
        let code = primary.replacingOccurrences(of: "_", with: "-")
            .split(separator: "-").first.map { $0.lowercased() } ?? "en"
        return supportedLanguages.contains(code) ? code : "en"
    }

    init(resources: URL? = Bundle.main.resourceURL, preferredLanguages: [String] = Locale.preferredLanguages) {
        language = Self.language(for: preferredLanguages)
        if let url = resources?.appendingPathComponent("\(language).lproj/Localizable.strings"),
           let data = try? Data(contentsOf: url),
           let strings = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] {
            translations = strings
        } else {
            translations = [:]
        }
    }

    func string(_ source: String, arguments: [CVarArg] = []) -> String {
        let value = translations[source] ?? source
        return arguments.isEmpty ? value : String(format: value, locale: Locale(identifier: language), arguments: arguments)
    }

    func themeTitle(id: String, original: String) -> String {
        if language == "ru" { return original }
        return string(Self.themeNames[id] ?? original)
    }

    private static let themeNames = [
        "rolex-submariner-date-black": "Rolex Submariner Date · Black · steel · 126610LN",
        "rolex-submariner-date-green": "Rolex Submariner Date · Green · steel · 126610LV",
        "rolex-submariner-date-blue-rolesor": "Rolex Submariner Date · Blue · steel and gold · 126613LB",
        "rolex-submariner-date-black-rolesor": "Rolex Submariner Date · Black · steel and gold · 126613LN",
        "rolex-submariner-date-black-gold": "Rolex Submariner Date · Black · yellow gold · 126618LN",
        "rolex-submariner-date-blue-gold": "Rolex Submariner Date · Blue · yellow gold · 126618LB",
        "rolex-submariner": "Rolex Submariner", "omega-speedmaster": "Omega Speedmaster Moonwatch",
        "cartier-tank": "Cartier Tank Must", "ap-royal-oak": "Audemars Piguet Royal Oak",
        "casio-gshock": "Casio G-Shock DW-5600",
        "minimalism": "Minimalism", "minimalism-24": "Minimalism 24",
        "minimalism-dark": "Minimalism — Dark", "minimalism-24-dark": "Minimalism 24 — Dark",
        "avangard": "Avangard 0292", "raketa-su": "Raketa Su 0331",
        "zolotoy-klyuchik": "Golden Key 0328", "sovremennik": "Contemporary 0352",
        "russkiy-kod-0302": "Russian Code 0302", "russkiy-kod-0344": "Russian Code Meridian 0344",
        "raketa-x-lebedev": "BIG ZERO Lebedev 0333", "baykonur-0325": "Baikonur 0325",
        "big-zero-yankovskaya": "BIG ZERO Yankovskaya 0330", "big-zero-azur-blue": "BIG ZERO Azure 0308",
        "amfibiya-0321": "Amphibian 0321", "kopernik-0293": "Copernicus 0307",
        "podvodnik-0317": "Submariner 0317", "polyarnye-0300": "Polar 0300",
        "letchik": "Pilot 0301", "big-zero-blue": "BIG ZERO Blue 0294",
        "big-zero-black-0341": "BIG ZERO Black 0341", "big-zero-0283": "BIG ZERO 0283",
        "raketa-avgvst-0316": "Raketa × Avgvst 0316 · Silver", "raketa-avgvst": "Raketa × Avgvst 0315 · Gold",
        "raketa-avgvst-0320": "Raketa × Avgvst 0320 · Black"
    ]
}

func L(_ source: String, _ arguments: CVarArg...) -> String {
    Localization.current.string(source, arguments: arguments)
}

extension ClockTheme {
    var localizedTitle: String { Localization.current.themeTitle(id: id, original: title) }
}
