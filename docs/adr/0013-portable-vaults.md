# ADR-0013: Independent password-protected calendar documents

Documentation updated: 2026-10-05.

## Context

The user requested KeePass-like ownership: independently named calendar vault files, chosen locations, and a separate password for each vault. The format should be Kansolendar's own .kanso, not KDBX.

## Decision reflected in the current source

Represent each portable vault as a SQLite document with encrypted records and an embedded password-wrapped random DEK. Open documents in separate windows/sessions. Offer manual password saving through Apple Passwords. Preserve the existing app-support Keychain vault separately.

## History and superseded assumptions

Recorded on 2026-10-05 from the user's explicit document/password requirements. This supersedes the original single-vault/no-password assumptions for portable mode. It does not add KeePass compatibility, passkeys, or automatic Passwords integration.

## Consequences

Renaming/copying a closed file retains identity and password. New vault creation refuses overwrite. Recovery uses a matching kit and the bounded restore rules, including empty unrelated destinations. Finder/multiple-window runtime validation remains pending. See [vault files](../kanso-vault-files.md) and [backups](../backups.md).

## Status

Implemented in source; current app/runtime verification pending. Current verification limits are tracked in [testing](../testing.md).
