/// Shared policy keeps preferences and the lock deadline independent of UI timers.
/// Durations use a monotonic clock supplied by the caller, never wall-clock dates.
public enum VaultIdlePolicy {
    public static let minuteChoices = [1, 2, 3, 4, 5, 10, 15, 30]
    public static let defaultMinutes = 5

    public static func validatedMinutes(_ value: Int) -> Int {
        minuteChoices.contains(value) ? value : defaultMinutes
    }

    public static func shouldLock(elapsedSeconds: Double, minutes: Int) -> Bool {
        elapsedSeconds >= Double(validatedMinutes(minutes) * 60)
    }
}
