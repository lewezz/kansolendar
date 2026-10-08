import Foundation
import Observation
import Testing
@testable import KansolendarAppState

@Suite("Application languages")
@MainActor
struct AppLanguageTests {
    private func withLocalization(_ body: (AppLocalization, UserDefaults) throws -> Void) rethrows {
        let suite = "kansolendar-language-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(AppLocalization(defaults: defaults), defaults)
    }

    @Test("English is primary regardless of system language; invalid saved choices fall back")
    func defaultLanguage() {
        withLocalization { localization, defaults in
            #expect(localization.language == .english)
            #expect(localization.string("Settings") == "Settings")
            defaults.set("unsupported", forKey: AppLanguage.storageKey)
            #expect(AppLocalization(defaults: defaults).language == .english)
        }
    }

    @Test("Each of the eleven supported choices survives a new app session")
    func persistence() {
        withLocalization { localization, defaults in
            #expect(AppLanguage.allCases.map(\.rawValue) == ["en", "es", "fr", "de", "it", "pt", "nl", "pl", "ja", "ko", "zh-Hans"])
            for language in AppLanguage.allCases {
                localization.language = language
                let restored = AppLocalization(defaults: defaults)
                #expect(restored.language == language)
                #expect(restored.locale == language.locale)
                #expect(!language.nativeName.isEmpty)
            }
        }
    }

    @Test("Lookup follows the chosen language and missing keys preserve their fallback")
    func translatedLabels() {
        let expected = ["Settings", "Ajustes", "Réglages", "Einstellungen", "Impostazioni", "Definições", "Instellingen", "Ustawienia", "設定", "설정", "设置"]
        withLocalization { localization, _ in
            for (language, settings) in zip(AppLanguage.allCases, expected) {
                localization.language = language
                #expect(localization.string("Settings") == settings)
                #expect(localization.string("unknown-source-key") == "unknown-source-key")
                let name = "Synthetic 50% %@ 日本語"
                #expect(localization.format("“%@” will be removed from this vault.", name).contains(name))
            }
        }
    }

    @Test("Polish plurals handle zero, one, few, many and teen counts")
    func polishPlurals() {
        withLocalization { localization, _ in
            localization.language = .polish
            for (count, expected) in [(0, "0 wydarzeń"), (1, "1 wydarzenie"), (2, "2 wydarzenia"), (5, "5 wydarzeń"), (12, "12 wydarzeń"), (21, "21 wydarzeń"), (22, "22 wydarzenia")] {
                #expect(localization.events(count) == expected)
            }
            #expect(localization.minutes(1) == "1 minuta")
            #expect(localization.minutes(2) == "2 minuty")
            #expect(localization.minutes(15) == "15 minut")
        }
    }

    @Test("Native plural formatting works in every bundled language")
    func allLanguagePlurals() {
        let minute = ["1 minute", "1 minuto", "1 minute", "1 Minute", "1 minuto", "1 minuto", "1 minuut", "1 minuta", "1分", "1분", "1 分钟"]
        let events = ["2 events", "2 eventos", "2 événements", "2 Termine", "2 eventi", "2 eventos", "2 afspraken", "2 wydarzenia", "2件のイベント", "2개 이벤트", "2 个日程"]
        withLocalization { localization, _ in
            for (index, language) in AppLanguage.allCases.enumerated() {
                localization.language = language
                #expect(localization.minutes(1) == minute[index])
                #expect(localization.events(2) == events[index])
                #expect(!localization.events(0).contains("%"))
                #expect(!localization.minutes(30).contains("%"))
            }
        }
    }

    @Test("Observation invalidates displayed text when the shared preference changes")
    func redrawObservation() async {
        await confirmation("Language change invalidates the observed presentation") { changed in
            withLocalization { localization, _ in
                withObservationTracking {
                    _ = localization.string("Settings")
                    _ = localization.locale
                } onChange: {
                    changed()
                }
                localization.language = .japanese
                #expect(localization.string("Settings") == "設定")
            }
        }
    }

    @Test("All shipped language tables contain the complete English keys and placeholders")
    func resourceCoverage() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Kansolendar/App/Resources")
        func strings(_ language: AppLanguage) throws -> [String: String] {
            let url = root.appendingPathComponent("\(language.rawValue).lproj/Localizable.strings")
            return try #require(PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: String])
        }
        let english = try strings(.english)
        let placeholders = try NSRegularExpression(pattern: "%(?:[0-9]+\\$)?(?:lld|@)")
        func formats(_ string: String) -> [String] {
            placeholders.matches(in: string, range: NSRange(string.startIndex..., in: string)).map {
                (string as NSString).substring(with: $0.range)
            }.sorted()
        }
        #expect(english.count >= 180)
        for language in AppLanguage.allCases {
            let table = try strings(language)
            #expect(Set(table.keys) == Set(english.keys))
            for (key, translation) in table {
                #expect(!translation.isEmpty)
                #expect(formats(translation) == formats(key))
            }
        }
    }
}
