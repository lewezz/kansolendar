import Foundation
import Observation

enum AppLanguage: String, CaseIterable, Identifiable {
    static let storageKey = "appLanguage"

    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case dutch = "nl"
    case polish = "pl"
    case japanese = "ja"
    case korean = "ko"
    case simplifiedChinese = "zh-Hans"

    var id: Self { self }

    // Native names let people find their language even before changing the UI.
    var nativeName: String {
        switch self {
        case .english: "English"
        case .spanish: "Español"
        case .french: "Français"
        case .german: "Deutsch"
        case .italian: "Italiano"
        case .portuguese: "Português"
        case .dutch: "Nederlands"
        case .polish: "Polski"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .simplifiedChinese: "简体中文"
        }
    }

    var locale: Locale {
        let identifier: String
        switch self {
        case .english: identifier = "en_US"
        case .spanish: identifier = "es_ES"
        case .french: identifier = "fr_FR"
        case .german: identifier = "de_DE"
        case .italian: identifier = "it_IT"
        case .portuguese: identifier = "pt_PT"
        case .dutch: identifier = "nl_NL"
        case .polish: identifier = "pl_PL"
        case .japanese: identifier = "ja_JP"
        case .korean: identifier = "ko_KR"
        case .simplifiedChinese: identifier = "zh_Hans_CN"
        }
        return Locale(identifier: identifier)
    }
}

/// App-wide presentation preference; changing it never recreates a vault session.
@MainActor
@Observable
final class AppLocalization {
    static let shared = AppLocalization()

    var language: AppLanguage {
        didSet { defaults.set(language.rawValue, forKey: AppLanguage.storageKey) }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let bundles: [AppLanguage: Bundle]

    init(defaults: UserDefaults = .standard, bundle: Bundle? = nil) {
        self.defaults = defaults
        language = defaults.string(forKey: AppLanguage.storageKey).flatMap(AppLanguage.init(rawValue:)) ?? .english
        #if SWIFT_PACKAGE
        let resources = bundle ?? Bundle.module
        #else
        let resources = bundle ?? Bundle.main
        #endif
        bundles = Dictionary(uniqueKeysWithValues: AppLanguage.allCases.compactMap { language in
            guard let path = resources.path(forResource: language.rawValue, ofType: "lproj"),
                  let localizedBundle = Bundle(path: path) else { return nil }
            return (language, localizedBundle)
        })
    }

    var locale: Locale { language.locale }

    func string(_ key: String) -> String {
        let fallback = bundles[.english]?.localizedString(forKey: key, value: key, table: nil) ?? key
        return bundles[language]?.localizedString(forKey: key, value: fallback, table: nil) ?? fallback
    }

    func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: locale, arguments: arguments)
    }

    func minutes(_ count: Int) -> String { format("duration_minutes", Int64(count)) }
    func events(_ count: Int) -> String { format("event_count", Int64(count)) }
}

@MainActor
enum L10n {
    static var locale: Locale { AppLocalization.shared.locale }
    static func string(_ key: String) -> String { AppLocalization.shared.string(key) }
    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), locale: locale, arguments: arguments)
    }
    static func minutes(_ count: Int) -> String { AppLocalization.shared.minutes(count) }
    static func events(_ count: Int) -> String { AppLocalization.shared.events(count) }
}
