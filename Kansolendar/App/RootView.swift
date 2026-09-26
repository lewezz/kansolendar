import KansolendarCore
import SwiftUI
#if DEBUG
import KansolendarStorage
#endif

struct RootView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text(KansolendarBuildInfo.productName)
                .font(.title2)
                .fontWeight(.semibold)
            Text("Local calendar foundation")
                .foregroundStyle(.secondary)
#if DEBUG
            KeychainValidationView()
#endif
        }
        .frame(minWidth: 520, minHeight: 360)
    }
}

#if DEBUG
private struct KeychainValidationView: View {
    @State private var status = "Not tested"
    @State private var isRunning = false

    var body: some View {
        VStack(spacing: 8) {
            Button("Test macOS Keychain presence") {
                runValidation()
            }
            .disabled(isRunning)

            Text(status)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 16)
    }

    private func runValidation() {
        isRunning = true
        status = "Waiting for Keychain…"

        Task {
            let account = UUID().uuidString
            let sample = Data(repeating: 0x5A, count: 32)
            let result = await Task.detached(priority: .userInitiated) {
                defer { try? KeychainProbe.delete(account: account) }
                var operation = "Create"
                do {
                    try KeychainProbe.store(sample, account: account)
                    operation = "Read"
                    let loaded = try KeychainProbe.load(account: account)
                    return loaded == sample ? "Protected item verified" : "Protected item mismatch"
                } catch KeychainProbeError.status(let code) {
                    return "\(operation) status: \(code)"
                } catch {
                    return "\(operation) failed"
                }
            }.value

            status = result
            isRunning = false
        }
    }
}
#endif
