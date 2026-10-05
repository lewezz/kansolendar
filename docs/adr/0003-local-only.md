# ADR-0003: Local operation without a backend

Documentation updated: 2026-10-05.

## Context

The user wants calendar ownership without trusting an account or server.

## Decision reflected in the current source

Calendar use is local. No account, backend, app network API, or network entitlement is part of the implementation.

## History and superseded assumptions

Offline operation was a product requirement, not a future option. Portable user-selected files extend local ownership without introducing a service.

## Consequences

Users manage their own document copies. Other software and the operating system can still use networks or synchronize user-selected directories. See [privacy](../privacy.md).

## Status

Implemented product boundary. Current verification limits are tracked in [testing](../testing.md).
