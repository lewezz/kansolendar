# ADR-0007: Actor ownership and session generations

Documentation updated: 2026-10-05.

## Context

Asynchronous authentication and loading can complete after a window is locked or closed.

## Decision reflected in the current source

Use MainActor for presentation, vault actors for storage, and generation IDs for key sessions and obsolete UI results. Keep transaction bodies synchronous and non-nested.

## History and superseded assumptions

Swift Concurrency was part of the original stack. Current isolation and generation checks are implemented. The original automatic-lock and cancel-every-task proposal is not implemented.

## Consequences

Actor isolation does not eliminate races across await or make C I/O nonblocking. UI tokens reject presentation results but do not cancel storage restoration. See [architecture](../architecture.md) and [testing](../testing.md).

## Status

Implemented mechanisms; lifecycle integration still pending verification. Current verification limits are tracked in [testing](../testing.md).
