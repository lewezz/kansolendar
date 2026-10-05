import AppKit
import SwiftUI

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

/// Preferences are shared across windows; each scene installs the accent environment.
private struct AppThemeModifier: ViewModifier {
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system.rawValue
    @AppStorage(AppAccent.storageKey) private var accent = AppAccent.cyan.rawValue

    func body(content: Content) -> some View {
        content
            .tint(selectedAccent.color)
            .environment(\.appAccentColor, selectedAccent.color)
            .onAppear(perform: applyAppearance)
            .onChange(of: appearance) { _, _ in applyAppearance() }
    }

    private var selectedAccent: AppAccent {
        AppAccent(rawValue: accent) ?? .cyan
    }

    private func applyAppearance() {
        // NSApp appearance is application-wide, matching the shared preference above.
        NSApp.appearance = (AppAppearance(rawValue: appearance) ?? .system).appKitAppearance
    }
}

private struct AppAccentColorKey: EnvironmentKey {
    static let defaultValue = Color.cyan
}

extension EnvironmentValues {
    var appAccentColor: Color {
        get { self[AppAccentColorKey.self] }
        set { self[AppAccentColorKey.self] = newValue }
    }
}

extension View {
    func appTheme() -> some View {
        modifier(AppThemeModifier())
    }
}

struct AppearanceSettingsView: View {
    @AppStorage(VaultLockSettings.storageKey) private var idleMinutes = 5
    @AppStorage(VaultRecentFiles.enabledKey) private var rememberRecentFiles = false
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system.rawValue
    @AppStorage(AppAccent.storageKey) private var accent = AppAccent.cyan.rawValue

    var body: some View {
        Form {
            Section("Privacy") {
                Toggle("Remember recent vault files", isOn: $rememberRecentFiles)
                    .onChange(of: rememberRecentFiles) { _, enabled in
                        if !enabled { VaultRecentFiles.clear() }
                    }
                Text("Recent files store their names and locations outside the encrypted vault.")
                    .font(.caption).foregroundStyle(.secondary)
                Picker("Lock after inactivity", selection: $idleMinutes) {
                    ForEach(VaultLockSettings.choices, id: \.self) { minutes in
                        Text("\(minutes) \(minutes == 1 ? "minute" : "minutes")").tag(minutes)
                    }
                }
                Text("Vaults also lock when the Mac locks or sleeps. Switching apps does not lock them.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Appearance") {
                Picker("Mode", selection: $appearance) {
                    ForEach(AppAppearance.allCases) { option in
                        Label(option.localizedName, systemImage: option.systemImage)
                            .tag(option.rawValue)
                    }
                }
                .pickerStyle(.segmented)

                Text("System follows the appearance configured in macOS.")
                    .font(.caption)
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
                                            .font(.system(size: 10, weight: .bold))
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
        .frame(width: 470, height: 440)
        .navigationTitle("Settings")
    }
}
