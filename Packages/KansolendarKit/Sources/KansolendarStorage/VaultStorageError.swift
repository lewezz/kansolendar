/// Internal persistence failures; the public facade maps these to safe UI categories.
internal enum VaultStorageError: Error, Equatable, Sendable {
    case fileInUse, fileChanged, vaultNotCreated, vaultAlreadyCreated, locked
    case corruptVault, duplicateUID, authenticationFailed, invalidInput, missingRecord
}
