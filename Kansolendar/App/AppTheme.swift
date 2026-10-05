import AppKit
import SwiftUI

enum AppWindowLayout {
    // Reserve room for readable toolbar labels, sidebar navigation and search.
    static let minimumWidth: CGFloat = 1_400
}

enum AppAppearance: String, CaseIterable, Identifiable {
    static let storageKey = "appAppearance"

    case system
    case light
    case dark

    var id: Self { self }

    var localizedName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon.stars"
        }
    }

    var appKitAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

enum AppAccent: String, CaseIterable, Identifiable {
    static let storageKey = "appAccent"

    case cyan
    case blue
    case indigo
    case purple
    case pink
    case orange
    case green

    var id: Self { self }

    var localizedName: String {
        switch self {
        case .cyan: "Cyan"
        case .blue: "Blue"
        case .indigo: "Indigo"
        case .purple: "Purple"
        case .pink: "Pink"
        case .orange: "Orange"
        case .green: "Green"
        }
    }

    var color: Color {
        switch self {
        case .cyan: .cyan
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .orange: .orange
        case .green: .green
        }
    }
}

enum AppFont: String, CaseIterable, Identifiable {
    static let storageKey = "appFont"

    case system, serif, rounded, monospaced
    case helveticaNeue, arial, avenir, georgia, timesNewRoman, verdana

    var id: Self { self }

    var localizedName: String {
        switch self {
        case .system: "System"
        case .serif: "Serif"
        case .rounded: "Rounded"
        case .monospaced: "Monospaced"
        case .helveticaNeue: "Helvetica Neue"
        case .arial: "Arial"
        case .avenir: "Avenir"
        case .georgia: "Georgia"
        case .timesNewRoman: "Times New Roman"
        case .verdana: "Verdana"
        }
    }

    var design: Font.Design {
        switch self {
        case .system: .default
        case .serif: .serif
        case .rounded: .rounded
        case .monospaced: .monospaced
        default: .default
        }
    }

    private var postScriptName: String? {
        switch self {
        case .helveticaNeue: "HelveticaNeue"
        case .arial: "ArialMT"
        case .avenir: "Avenir-Book"
        case .georgia: "Georgia"
        case .timesNewRoman: "TimesNewRomanPSMT"
        case .verdana: "Verdana"
        default: nil
        }
    }

    func resolvedFont(_ style: Font.TextStyle, size: CGFloat? = nil, weight: Font.Weight? = nil) -> Font {
        let pointSize = size ?? NSFont.preferredFont(forTextStyle: nativeStyle(style)).pointSize
        if let name = postScriptName, NSFont(name: name, size: pointSize) != nil {
            return (size == nil ? Font.custom(name, size: pointSize, relativeTo: style) : Font.custom(name, fixedSize: pointSize))
                .weight(weight ?? (style == .headline ? .semibold : .regular))
        }
        // Missing local font families fall back without downloading any font data.
        return size.map { Font.system(size: $0, weight: weight ?? .regular, design: design) }
            ?? Font.system(style, design: design, weight: weight)
    }

    private func nativeStyle(_ style: Font.TextStyle) -> NSFont.TextStyle {
        switch style {
        case .largeTitle: .largeTitle
        case .title: .title1
        case .title2: .title2
        case .title3: .title3
        case .headline: .headline
        case .subheadline: .subheadline
        case .callout: .callout
        case .footnote: .footnote
        case .caption: .caption1
        case .caption2: .caption2
        default: .body
        }
    }
}

private struct AppFontKey: EnvironmentKey {
    static let defaultValue = AppFont.system
}

/// Explicit text styles must resolve through the selected family as well as body text.
private struct AppTextFontModifier: ViewModifier {
    @Environment(\.appFont) private var family
    let style: Font.TextStyle
    let size: CGFloat?
    let weight: Font.Weight?

    func body(content: Content) -> some View {
        content.font(family.resolvedFont(style, size: size, weight: weight))
    }
}

/// Preferences are shared across windows; each scene installs the theme environment.
private struct AppThemeModifier: ViewModifier {
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system.rawValue
    @AppStorage(AppAccent.storageKey) private var accent = AppAccent.cyan.rawValue
    @AppStorage(AppFont.storageKey) private var font = AppFont.system.rawValue

    func body(content: Content) -> some View {
        content
            .environment(\.appFont, selectedFont)
            .font(selectedFont.resolvedFont(.body))
            .tint(selectedAccent.color)
            .environment(\.appAccentColor, selectedAccent.color)
            .onAppear(perform: applyAppearance)
            .onChange(of: appearance) { _, _ in applyAppearance() }
    }

    private var selectedAccent: AppAccent {
        AppAccent(rawValue: accent) ?? .cyan
    }

    private var selectedFont: AppFont { AppFont(rawValue: font) ?? .system }

    private func applyAppearance() {
        // NSApp appearance is application-wide, matching the shared preference above.
        NSApp.appearance = (AppAppearance(rawValue: appearance) ?? .system).appKitAppearance
    }
}

private struct AppAccentColorKey: EnvironmentKey {
    static let defaultValue = Color.cyan
}

extension EnvironmentValues {
    var appFont: AppFont {
        get { self[AppFontKey.self] }
        set { self[AppFontKey.self] = newValue }
    }

    var appAccentColor: Color {
        get { self[AppAccentColorKey.self] }
        set { self[AppAccentColorKey.self] = newValue }
    }
}

extension View {
    func appTextFont(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> some View {
        modifier(AppTextFontModifier(style: style, size: nil, weight: weight))
    }

    func appTextFont(size: CGFloat, weight: Font.Weight? = nil) -> some View {
        modifier(AppTextFontModifier(style: .body, size: size, weight: weight))
    }

    func appTheme() -> some View {
        modifier(AppThemeModifier())
    }
}

struct AppearanceSettingsView: View {
    @AppStorage(VaultLockSettings.storageKey) private var idleMinutes = 5
    @AppStorage(VaultRecentFiles.enabledKey) private var rememberRecentFiles = false
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system.rawValue
    @AppStorage(AppAccent.storageKey) private var accent = AppAccent.cyan.rawValue
    @AppStorage(AppFont.storageKey) private var font = AppFont.system.rawValue

    var body: some View {
        Form {
            Section("Privacy") {
                Toggle("Remember recent vault files", isOn: $rememberRecentFiles)
                    .onChange(of: rememberRecentFiles) { _, enabled in
                        if !enabled { VaultRecentFiles.clear() }
                    }
                Text("Recent files store their names and locations outside the encrypted vault.")
                    .appTextFont(.caption).foregroundStyle(.secondary)
                Picker("Lock after inactivity", selection: $idleMinutes) {
                    ForEach(VaultLockSettings.choices, id: \.self) { minutes in
                        Text("\(minutes) \(minutes == 1 ? "minute" : "minutes")").tag(minutes)
                    }
                }
                Text("Vaults also lock when the Mac locks or sleeps. Switching apps does not lock them.")
                    .appTextFont(.caption).foregroundStyle(.secondary)
            }
            Section("Appearance") {
                Picker("Font", selection: $font) {
                    ForEach(AppFont.allCases) { option in
                        Text(option.localizedName).tag(option.rawValue)
                    }
                }
                Text("Calendar preview · Aa Bb Cc · 0123456789")
                    .appTextFont(.body)
                    .foregroundStyle(.secondary)

                Picker("Mode", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { option in
                        Label(option.localizedName, systemImage: option.systemImage)
                            .tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Text("System follows the appearance configured in macOS.")
                    .appTextFont(.caption)
                    .foregroundStyle(.secondary)

                LabeledContent("Accent color") {
                    HStack(spacing: 12) {
                        ForEach(AppAccent.allCases) { option in
                            Button {
                                accent = option.rawValue
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(option.color)
                                        .frame(width: 22, height: 22)
                                    if accent == option.rawValue {
                                        Image(systemName: "checkmark")
                                            .appTextFont(size: 10, weight: .bold)
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(option.localizedName)
                            .accessibilityAddTraits(accent == option.rawValue ? .isSelected : [])
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .frame(width: 470, height: 520)
        .navigationTitle("Settings")
    }
}
