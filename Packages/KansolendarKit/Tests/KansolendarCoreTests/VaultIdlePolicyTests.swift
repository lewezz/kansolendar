import KansolendarCore
import Testing

struct VaultIdlePolicyTests {
    @Test func requestedIntervalsAndDefault() {
        #expect(VaultIdlePolicy.minuteChoices == [1, 2, 3, 4, 5, 10, 15, 30])
        #expect(VaultIdlePolicy.validatedMinutes(0) == 5)
        #expect(VaultIdlePolicy.validatedMinutes(-1) == 5)
        #expect(VaultIdlePolicy.validatedMinutes(60) == 5)
    }

    @Test(arguments: VaultIdlePolicy.minuteChoices)
    func deadlineBoundary(minutes: Int) {
        let deadline = Double(minutes * 60)
        #expect(!VaultIdlePolicy.shouldLock(elapsedSeconds: deadline - 0.01, minutes: minutes))
        #expect(VaultIdlePolicy.shouldLock(elapsedSeconds: deadline, minutes: minutes))
        #expect(VaultIdlePolicy.shouldLock(elapsedSeconds: deadline + 1, minutes: minutes))
        #expect(!VaultIdlePolicy.shouldLock(elapsedSeconds: 0, minutes: minutes))
    }
}
