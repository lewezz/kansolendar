# ADR-0004: Authenticated payload encryption

Documentation updated: 2026-10-05.

## Context

Copied vaults should not expose event content without a key, while the stack uses system SQLite and native cryptographic APIs.

## Decision reflected in the current source

Seal versioned payloads with CryptoKit AES-256-GCM using a random vault key and fresh nonce. Bind vault/key/record/parent identity in AAD. Keep the versioned KNSL envelope format explicit.

## History and superseded assumptions

The owner accepted payload encryption with visible structural metadata on 2026-09-25. The implementation does not provide whole-file/page encryption or an authenticated inventory.

## Consequences

Identifiers, relationships, counts, and sizes remain visible. Valid old copies and some deletion cannot be detected as adversarial replay. No independent audit or latest-tree verification is asserted. See [security](../security.md).

## Status

Implemented in source; original metadata-exposure decision retained. Current verification limits are tracked in [testing](../testing.md).
