import KansolendarStorage

/// User-facing text belongs to the app, keeping storage errors independent of presentation.
extension VaultError {
    var userMessage: String {
        switch self {
        case .fileInUse:
            "This vault is already open for editing. Close its other window or application first."
        case .fileChanged:
            "The file changed outside Kansolendar. It was not overwritten. Close and reopen it to continue."
        case .authenticationFailed:
            "Authentication failed. Check the vault password and try again. The calendar remains locked."
        case .corruptVault:
            "The vault failed its integrity check; its files will be preserved."
        case .unsupportedFormat:
            "This vault uses a format that this version cannot open."
        case .vaultAlreadyCreated:
            "This vault file has already been created."
        case .vaultNotCreated:
            "This vault file has not been created yet."
        case .locked:
            "The calendar is locked."
        case .conflict, .duplicateUID:
            "The operation conflicts with existing data."
        case .timeZoneRulesChanged:
            "System time-zone rules changed; review saved times before editing them."
        case .invalidInput:
            "The operation data is invalid. The calendar was not changed."
        case .queryLimitExceeded:
            "The search is too broad. Narrow the range and try again."
        case .storageUnavailable:
            "The local vault is unavailable. No partial information was shown."
        }
    }
}
