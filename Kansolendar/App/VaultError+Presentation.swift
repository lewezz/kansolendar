import KansolendarStorage

/// User-facing text belongs to the app, keeping storage errors independent of presentation.
extension VaultError {
    var userMessage: String {
        switch self {
        case .restoreRecoveryRequired:
            "Restore and rollback failed. The calendar is locked. Encrypted safety copies were retained; keep your backup and recovery kit for recovery."
        case .authenticationCancelled:
            "Authentication cancelled. The calendar remains locked."
        case .authenticationFailed:
            "Authentication failed. Check the vault password and try again. The calendar remains locked."
        case .keychainUnavailable:
            "macOS could not access secure storage. The calendar was not unlocked."
        case .recoveryRequired:
            "The original key is missing. A replacement will not be generated automatically."
        case .corruptVault:
            "The vault failed its integrity check; its files will be preserved."
        case .unsupportedFormat:
            "This vault uses a format that this version cannot open."
        case .vaultAlreadyCreated:
            "A private calendar already exists on this Mac."
        case .vaultNotCreated:
            "A private calendar has not been created yet."
        case .locked:
            "The calendar is locked."
        case .conflict, .duplicateUID:
            "The operation conflicts with existing data."
        case .timeZoneRulesChanged:
            "System time-zone rules changed; review saved times before editing them."
        case .unlockInProgress:
            "An authentication request is already in progress."
        case .invalidInput:
            "The operation data is invalid. The calendar was not changed."
        case .queryLimitExceeded:
            "The search is too broad. Narrow the range and try again."
        case .storageUnavailable:
            "The local vault is unavailable. No partial information was shown."
        }
    }
}
