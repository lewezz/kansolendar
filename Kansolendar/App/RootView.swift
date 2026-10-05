import AppKit
import KansolendarCore
import SwiftUI

struct RootView: View {
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @AppStorage(VaultRecentFiles.enabledKey) private var rememberRecentFiles = false
    @State private var recentFiles: [URL] = []
    @State private var model: VaultViewModel

    init(portableFileURL: URL? = nil) {
        _model = State(initialValue: VaultViewModel(portableFileURL: portableFileURL))
    }

    var body: some View {
        Group {
            if model.vaultState == .unlocked {
                CalendarWorkspaceView(model: model)
            } else {
                vaultGate
            }
        }
        .frame(minWidth: AppWindowLayout.minimumWidth, minHeight: 700)
        .navigationTitle(model.portableFileURL.map { "Kansolendar — \($0.lastPathComponent)" } ?? "Kansolendar")
        .navigationSubtitle(model.portableFileURL.map {
            ($0.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
        } ?? "")
        .background(VaultWindowAttachment(model: model).frame(width: 0, height: 0))
        .task { await model.start() }
        .onAppear { recentFiles = VaultRecentFiles.urls }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            recentFiles = VaultRecentFiles.urls
        }
        .onOpenURL { url in
            guard KansoOpenPanelFilter.accepts(url) else { return }
            guard model.portableFileURL?.standardizedFileURL != url.standardizedFileURL else { return }
            openVaultWindow(url)
        }
        .onDisappear { model.closeDocument() }
        .sheet(item: $model.passwordSheet) { _ in
            VaultPasswordView(model: model)
                .interactiveDismissDisabled()
        }
    }

    private var vaultGate: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                HStack(spacing: 14) {
                    Image("KansolendarLogo")
                        .resizable().scaledToFit().frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(KansolendarBuildInfo.productName).font(.title2.weight(.semibold))
                        Text("PRIVATE CALENDARS")
                            .font(.caption.weight(.medium)).tracking(1.5).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label("Offline", systemImage: "lock.shield")
                        .font(.callout).foregroundStyle(.secondary)
                }

                if model.isPortableDocument {
                    documentGate
                } else {
                    welcome
                }

                if let message = model.message {
                    Label(message, systemImage: "info.circle")
                        .font(.callout).foregroundStyle(.secondary)
                        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                        .background(appAccentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("vault-message")
                }
                Divider()
                HStack {
                    Label("Encrypted files. Independent passwords.", systemImage: "lock.doc")
                    Spacer()
                    Text("No accounts · No servers · No sync")
                }
                .font(.caption).foregroundStyle(.secondary)
            }
            .padding(48).frame(maxWidth: 960)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Your time, kept private.")
                    .font(.system(size: 36, weight: .semibold))
                Text("Keep your calendars in a password-protected .kanso file. Choose where it lives and open it whenever you need it.")
                    .font(.body).foregroundStyle(.secondary).frame(maxWidth: 600, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .top, spacing: 18) {
                welcomeAction(title: "Create a vault", description: "Start with a new file, your own name and a unique password.", symbol: "doc.badge.plus", primary: true, action: createKansoFile)
                welcomeAction(title: "Open a vault", description: "Choose an existing .kanso file and unlock it with its password.", symbol: "folder", primary: false, action: openKansoFile)
            }
            if rememberRecentFiles {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent vaults").font(.headline)
                        Spacer()
                        if !recentFiles.isEmpty {
                            Button("Clear history") { VaultRecentFiles.clear() }.buttonStyle(.link)
                        }
                    }
                    if recentFiles.isEmpty {
                        Text("Files you open will appear here.").foregroundStyle(.secondary)
                    } else {
                        ForEach(recentFiles, id: \.self) { url in
                            Button {
                                openVaultWindow(url)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "lock.doc").foregroundStyle(appAccentColor)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(url.deletingPathExtension().lastPathComponent).font(.body.weight(.medium))
                                        Text((url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath)
                                            .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                                }
                                .padding(12).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }
        }
    }

    private func welcomeAction(title: String, description: String, symbol: String, primary: Bool, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: symbol).font(.title2).foregroundStyle(appAccentColor).accessibilityHidden(true)
            Text(title).font(.title3.weight(.semibold))
            Text(description).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            if primary {
                Button("Create Vault…", action: action).buttonStyle(.borderedProminent).controlSize(.large)
            } else {
                Button("Open Vault…", action: action).buttonStyle(.bordered).controlSize(.large)
            }
        }
        .padding(24).frame(maxWidth: .infinity, minHeight: 200, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(appAccentColor.opacity(primary ? 0.3 : 0.1)))
    }

    private var documentGate: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text(model.displayName ?? "Calendar vault").font(.largeTitle.weight(.semibold))
                Text(model.vaultState == .notCreated ? "Choose a unique password for this vault." : "Unlock your calendars with this file’s password.")
                    .foregroundStyle(.secondary)
            }
            statePanel
        }
        .padding(28).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var statePanel: some View {
        if model.isBusy {
            ProgressView("Preparing encrypted storage…")
        } else {
            switch model.vaultState {
            case .notCreated:
                VStack(alignment: .leading, spacing: 12) {
                    SecureField("Password (at least 15 characters)", text: $model.passwordInput)
                        .accessibilityIdentifier("new-vault-password")
                    SecureField("Confirm password", text: $model.passwordConfirmation)
                        .accessibilityIdentifier("confirm-vault-password")
                        .onSubmit { if model.canCreatePassword { model.createVault() } }
                    Text("Use a long, unique phrase. Spaces and symbols are allowed.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Create Vault", systemImage: "lock.shield") { model.createVault() }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        .disabled(!model.canCreatePassword).accessibilityIdentifier("create-vault")
                }.textFieldStyle(.roundedBorder).frame(maxWidth: 400)
            case .locked:
                VStack(alignment: .leading, spacing: 12) {
                    SecureField("Vault password", text: $model.passwordInput)
                        .textFieldStyle(.roundedBorder).accessibilityIdentifier("vault-password")
                        .onSubmit { if !model.passwordInput.isEmpty { model.unlock(password: model.passwordInput) } }
                    Button("Unlock Vault", systemImage: "lock.open") { model.unlock(password: model.passwordInput) }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        .disabled(model.passwordInput.isEmpty).accessibilityIdentifier("unlock-vault")
                    Text("You can paste a password saved in your password manager.")
                        .font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: 400)
            case .unlocking:
                ProgressView("Decrypting vault…")
            case .corrupt:
                Label("This file cannot be opened", systemImage: "exclamationmark.triangle").font(.headline)
                Text("Choose a file created with the current version of Kansolendar.")
                    .foregroundStyle(.secondary)
                Button("Open Another Vault…", action: openKansoFile).controlSize(.large)
            case .unlocked, nil:
                EmptyView()
            }
        }
    }

    private func createKansoFile() {
        guard let url = VaultFilePanel.chooseKansoDestination() else { return }
        openVaultWindow(url)
    }

    private func openKansoFile() {
        guard let url = VaultFilePanel.chooseKansoToOpen() else { return }
        openVaultWindow(url)
    }

    private func openVaultWindow(_ url: URL) {
        openWindow(id: "kanso-vault", value: url)
        // Only replace the welcome window; existing vault sessions stay open.
        if !model.isPortableDocument { dismiss() }
    }
}

/// The same concealed-password component is used after each new document creation.
struct VaultPasswordView: View {
    @Bindable var model: VaultViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Your vault is ready", systemImage: "checkmark.shield").font(.title2.weight(.semibold))
            Text("Keep this password somewhere safe. You can save it manually in Apple Passwords.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Group {
                    if model.isPasswordRevealed, let password = model.passwordToSave {
                        ScrollView(.horizontal) {
                            Text(password).textSelection(.enabled)
                                .fixedSize()
                        }
                        .frame(height: 32)
                    } else {
                        Text("••••••••••••••••")
                            .accessibilityLabel("Password hidden")
                    }
                }
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                Button(model.isPasswordRevealed ? "Hide" : "Reveal", systemImage: model.isPasswordRevealed ? "eye.slash" : "eye") {
                    model.isPasswordRevealed.toggle()
                }
            }
            .padding(14).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            HStack {
                Button("Copy Password", systemImage: "doc.on.doc") {
                    if let password = model.passwordToSave {
                        VaultPasswordClipboard.copy(password)
                    }
                }.buttonStyle(.bordered)
                Button("Open Passwords") { model.openPasswords() }.buttonStyle(.bordered)
                Spacer()
                Button("Continue") { model.finishPasswordPresentation() }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
            Text("If you forget the password, you lose access to this vault.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(28).frame(width: 520)
    }

}
