# ADR-0005: Local Keychain custody and separate recovery

Documentation updated: 2026-10-05.

## Context

The original app-support vault needed a random key, local presence-based unlock, and a recovery path without a user account.

## Decision reflected in the current source

Keep the local store's random DEK in a non-synchronizing device-only Keychain item with userPresence. Export recovery material only through an explicit separate key-bearing kit.

## History and superseded assumptions

Local presence authentication and separate recovery were accepted in the original design, with a clarification recorded on 2026-09-26. The original prohibition of a vault password is superseded for portable documents by [ADR-0013](0013-portable-vaults.md); the local backend remains separate.

## Consequences

Signing/access-group continuity affects the local key. Portable files do not depend on this item. Historical Keychain experiments do not prove the latest artifact works. See [key management](../key-management.md).

## Status

Implemented for the local store; portable mode recorded separately. Current verification limits are tracked in [testing](../testing.md).
