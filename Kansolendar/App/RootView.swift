import AppKit
import KansolendarCore
import SwiftUI

struct RootView: View {
    @Environment(\.appAccentColor) private var appAccentColor
    @Environment(\.openWindow) private var openWindow
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
        .frame(minWidth: 1_100, minHeight: 700)
        .task { await model.start() }
        .onOpenURL { url in
            guard url.isFileURL, url.pathExtension.lowercased() == "kanso" else { return }
            guard model.portableFileURL?.standardizedFileURL != url.standardizedFileURL else { return }
            openWindow(id: "kanso-vault", value: url)
        }
        .onDisappear { model.closeDocument() }
        .sheet(item: $model.passwordSheet) { sheet in
            if sheet == .save, let password = model.passwordToSave {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Save your vault password").font(.title2.weight(.semibold))
                    Text("Copy your password and save it in Apple Passwords. Later, retrieve it with Touch ID or your Mac password and paste it to unlock. Kansolendar cannot save it directly to Passwords.")
                        .foregroundStyle(.secondary)
                    Text(password)
                        .font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    HStack {
                        Button("Copy & open Passwords") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(password, forType: .string)
                            model.openPasswords()
                        }.buttonStyle(.borderedProminent)
                        Button("Done") { model.finishPasswordPresentation() }
                    }
                    Text("If you lose both this password and your recovery kit, the vault cannot be opened.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(24).frame(width: 480)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Choose a password for the restored vault")
                        .font(.title2.weight(.semibold))
                    SecureField("Password (at least 15 characters)", text: $model.passwordInput)
                    SecureField("Confirm password", text: $model.passwordConfirmation)
                    Text("Use at least 15 characters. Spaces and symbols are allowed; avoid reusing another password.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("Use a long, unique password. You can save it in Apple Passwords after restoring.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Restore and continue") { model.restorePendingBackup() }
                        .buttonStyle(.borderedProminent)
                        .disabled(!model.canCreatePassword || model.isBusy)
                }.padding(24).frame(width: 440)
            }
        }
        .interactiveDismissDisabled(model.passwordSheet != nil)
    }

    private var vaultGate: some View {
        VStack(spacing: 18) {
            Image("KansolendarLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(appAccentColor.opacity(0.35), lineWidth: 1)
                }
                .accessibilityHidden(true)

            Text(model.displayName ?? KansolendarBuildInfo.productName)
                .font(.largeTitle.monospaced().weight(.semibold))
                .tracking(1.2)

            Text("LOCAL / ENCRYPTED / OFFLINE")
                .font(.caption.monospaced().weight(.semibold))
                .foregroundStyle(.secondary)

            statePanel
                .padding(.top, 8)

            if !model.isPortableDocument {
                HStack {
                    Button("Create Vault File…", systemImage: "doc.badge.plus") { createKansoFile() }
                    Button("Open Vault File…", systemImage: "doc.badge.arrow.up") { openKansoFile() }
                }
                .buttonStyle(.bordered)
            }

            if let message = model.message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(appAccentColor.opacity(0.07), in: Capsule())
                    .accessibilityIdentifier("vault-message")
            }

            Text("Your calendar stays on this Mac. No accounts. No servers. No sync.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .frame(minWidth: 520, minHeight: 360)
        .padding(32)
        .background(appAccentColor.opacity(0.025))
    }

    @ViewBuilder
    private var statePanel: some View {
        if model.isBusy {
            ProgressView("Preparing encrypted storage…")
                .controlSize(.small)
        } else {
            switch model.vaultState {
            case .notCreated:
                if model.isPortableDocument {
                    SecureField("Create a password (at least 15 characters)", text: $model.passwordInput)
                        .textFieldStyle(.roundedBorder).frame(maxWidth: 320)
                        .accessibilityIdentifier("new-vault-password")
                    SecureField("Confirm password", text: $model.passwordConfirmation)
                        .textFieldStyle(.roundedBorder).frame(maxWidth: 320)
                        .accessibilityIdentifier("confirm-vault-password")
                    Text("Use at least 15 characters. Spaces and symbols are allowed; avoid reusing another password.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Create Calendar Vault", systemImage: "lock.shield") { model.createVault() }
                        .controlSize(.large).buttonStyle(.borderedProminent)
                        .disabled(!model.canCreatePassword)
                        .accessibilityIdentifier("create-vault")
                } else {
                    Button("Create Private Vault", systemImage: "lock.shield") { model.createVault() }
                        .controlSize(.large).buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("create-vault")
                    Text("The key is generated on this Mac. No account required.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            case .locked:
                if model.requiresPassword {
                    SecureField("Vault password", text: $model.passwordInput)
                        .textFieldStyle(.roundedBorder).frame(maxWidth: 320)
                        .accessibilityIdentifier("vault-password")
                    Button("Unlock Vault", systemImage: "lock.open") { model.unlock(password: model.passwordInput) }
                        .controlSize(.large).buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("unlock-vault")
                    Text("Retrieve your saved password from Passwords with Touch ID or your Mac password, then paste it here.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Button("Retry Unlock", systemImage: "touchid") { model.unlock() }
                        .controlSize(.large).buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("unlock-vault")
                    Text("Touch ID or your Mac password unlocks the local key.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            case .unlocked:
                Label("Private vault unlocked", systemImage: "lock.open.fill")
                    .font(.headline)
                    .foregroundStyle(appAccentColor)
                Text("Calendar data is available for this session.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Lock Now", systemImage: "lock") {
                    model.lock()
                }
                .accessibilityIdentifier("lock-vault")
            case .unlocking:
                ProgressView("Waiting for macOS authentication…")
                    .controlSize(.small)
            case .recoveryRequired:
                Label("Key recovery required", systemImage: "exclamationmark.lock")
                    .font(.headline)
                Text("Choose an encrypted backup and its matching recovery kit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Restore Backup…", systemImage: "externaldrive.badge.timemachine") {
                    chooseAndRestoreBackup()
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
            case .corrupt:
                Label("The vault cannot be opened", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                Text("Your data will be preserved without being overwritten.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case nil:
                Label("Local vault unavailable", systemImage: "externaldrive.badge.exclamationmark")
                    .font(.headline)
            }
        }
    }

    private func chooseAndRestoreBackup() {
        guard let backup = ExportPanel.chooseBackupForRestore(),
              let kit = ExportPanel.chooseRecoveryKitForRestore() else { return }
        Task { await model.restoreBackup(at: backup, recoveryKitURL: kit) }
    }

    private func createKansoFile() {
        guard let url = ExportPanel.chooseKansoDestination() else { return }
        openWindow(id: "kanso-vault", value: url)
    }

    private func openKansoFile() {
        guard let url = ExportPanel.chooseKansoToOpen() else { return }
        openWindow(id: "kanso-vault", value: url)
    }
}
