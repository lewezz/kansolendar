# ADR-0009: No telemetry or remote diagnostics

Documentation updated: 2026-10-05.

## Context

Usage measurement and remote diagnostic services would move information outside the local calendar.

## Decision reflected in the current source

Do not add analytics, advertising, telemetry SDKs, remote crash submissions, or startup version checks. Current errors are local UI messages.

## History and superseded assumptions

No analytics or telemetry was fixed by the original requirements. No persistent application logger or support-bundle facility has been implemented.

## Consequences

Future diagnostics need explicit local design and sanitized categories. The app does not control operating-system diagnostics. See [errors and logging](../logging.md).

## Status

Implemented product boundary. Current verification limits are tracked in [testing](../testing.md).
