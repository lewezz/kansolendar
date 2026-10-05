# ADR-0008: No application-managed synchronization

Documentation updated: 2026-10-05.

## Context

Calendar data should stay under local file ownership without a service or synchronization engine.

## Decision reflected in the current source

Do not implement CloudKit, CalDAV, subscriptions, background synchronization, or a remote conflict-resolution service.

## History and superseded assumptions

No synchronization was an original product requirement. Named portable vaults change document ownership, not that requirement.

## Consequences

Users can copy files themselves or select externally synchronized folders. Copies retain identity and are not automatically merged or kept fresh. See [vault files](../kanso-vault-files.md).

## Status

Implemented product boundary. Current verification limits are tracked in [testing](../testing.md).
