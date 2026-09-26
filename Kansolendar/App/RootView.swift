import KansolendarCore
import KansolendarStorage
import SwiftUI

struct RootView: View {
    @State private var model = VaultViewModel()

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "calendar.badge.lock")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(.tint)

            Text(KansolendarBuildInfo.productName)
                .font(.largeTitle.weight(.semibold))

            Text("Tu calendario permanece en este Mac.")
                .foregroundStyle(.secondary)

            statePanel
                .padding(.top, 8)

            if let message = model.message {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
                    .accessibilityIdentifier("vault-message")
            }

            Text("Sin cuentas, servidores ni sincronización.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .frame(minWidth: 520, minHeight: 360)
        .padding(32)
        .task { await model.refresh() }
    }

    @ViewBuilder
    private var statePanel: some View {
        if model.isBusy {
            ProgressView("Preparando el almacén privado…")
                .controlSize(.small)
        } else {
            switch model.vaultState {
            case .notCreated:
                Button("Crear calendario privado", systemImage: "lock.shield") {
                    model.createVault()
                }
                .controlSize(.large)
                .accessibilityIdentifier("create-vault")
                Text("La clave se genera en este Mac. No necesitas crear una cuenta.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .locked:
                Button("Desbloquear calendario", systemImage: "lock.open") {
                    model.unlock()
                }
                .controlSize(.large)
                .accessibilityIdentifier("unlock-vault")
                Text("macOS solicitará autenticación para usar la clave local.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .unlocked:
                Label("Almacén privado desbloqueado", systemImage: "lock.open.fill")
                    .font(.headline)
                Text("La agenda todavía está en construcción.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Bloquear ahora", systemImage: "lock") {
                    model.lock()
                }
                .accessibilityIdentifier("lock-vault")
            case .unlocking:
                ProgressView("Esperando autenticación de macOS…")
                    .controlSize(.small)
            case .recoveryRequired:
                Label("Se necesita recuperar la clave", systemImage: "exclamationmark.lock")
                    .font(.headline)
                Text("No se ha creado una clave de reemplazo. La recuperación aún no está disponible.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            case .corrupt:
                Label("No se puede abrir el almacén", systemImage: "exclamationmark.triangle")
                    .font(.headline)
                Text("Los datos se conservarán sin sobrescribirlos.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case nil:
                Label("Almacén local no disponible", systemImage: "externaldrive.badge.exclamationmark")
                    .font(.headline)
            }
        }
    }
}

@MainActor
@Observable
private final class VaultViewModel {
    private let vault: KansolendarVault?
    private(set) var vaultState: VaultState?
    private(set) var isBusy = false
    var message: String?

    init() {
        do {
            vault = try KansolendarVault()
        } catch {
            vault = nil
            message = "No se pudo preparar el almacén local. No se ha guardado información personal."
        }
    }

    func refresh() async {
        guard let vault else { return }
        do {
            vaultState = try await vault.state()
        } catch let error as VaultError {
            message = Self.message(for: error)
        } catch {
            message = "No se pudo consultar el estado del almacén local."
        }
    }

    func createVault() {
        guard let vault else { return }
        isBusy = true
        message = nil
        Task {
            defer { isBusy = false }
            do {
                _ = try await vault.createVault()
                vaultState = try await vault.state()
            } catch let error as VaultError {
                message = Self.message(for: error)
                await refresh()
            } catch {
                message = "No se pudo crear el almacén privado. No se ha guardado información personal."
                await refresh()
            }
        }
    }

    func unlock() {
        guard let vault else { return }
        isBusy = true
        message = nil
        vaultState = .unlocking
        Task {
            defer { isBusy = false }
            do {
                try await vault.unlock()
                vaultState = try await vault.state()
            } catch let error as VaultError {
                message = Self.message(for: error)
                await refresh()
            } catch {
                message = "No se pudo desbloquear el almacén local."
                await refresh()
            }
        }
    }

    func lock() {
        guard let vault else { return }
        Task {
            await vault.lock()
            await refresh()
        }
    }

    private static func message(for error: VaultError) -> String {
        switch error {
        case .authenticationCancelled:
            "Autenticación cancelada. El calendario sigue bloqueado."
        case .authenticationFailed:
            "macOS no autorizó el acceso. El calendario sigue bloqueado."
        case .keychainUnavailable:
            "macOS no pudo acceder al almacén seguro. El calendario no se ha desbloqueado."
        case .recoveryRequired:
            "Falta la clave original. No se generará otra automáticamente."
        case .corruptVault:
            "El almacén no superó la comprobación de integridad; se conservarán sus archivos."
        case .unsupportedFormat:
            "Este almacén usa un formato que esta versión no puede abrir."
        case .vaultAlreadyCreated:
            "Ya existe un calendario privado en este Mac."
        case .vaultNotCreated:
            "Todavía no se ha creado un calendario privado."
        case .locked:
            "El calendario está bloqueado."
        case .conflict, .duplicateUID:
            "La operación entra en conflicto con datos existentes."
        case .timeZoneRulesChanged:
            "Las reglas horarias del sistema cambiaron; revisa las horas guardadas antes de editarlas."
        case .unlockInProgress:
            "Ya hay una solicitud de autenticación en curso."
        case .invalidInput:
            "Los datos de la operación no son válidos. No se ha modificado el calendario."
        case .queryLimitExceeded:
            "La búsqueda es demasiado amplia. Acota el intervalo y vuelve a intentarlo."
        case .storageUnavailable:
            "El almacén local no está disponible. No se ha mostrado información parcial."
        }
    }
}
