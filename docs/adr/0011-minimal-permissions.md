# ADR-0011: Sandbox and selected-file access

Documentation updated: 2026-10-05.

## Context

Independent file-based calendars need controlled document access without reading system calendars or granting broad disk access.

## Decision reflected in the current source

Declare the app sandbox, user-selected file read/write access, and the app's Keychain group. Keep network and unrelated system-service entitlements absent.

## History and superseded assumptions

Minimal permissions were in the initial design. Current entitlements and file panels implement that boundary; portable document access is now part of the lifecycle.

## Consequences

No EventKit, contacts, location, notification, or broad disk entitlement exists. Source declarations require verification on the eventual signed artifact. Clipboard/export/OS behavior remains outside vault encryption. See [privacy](../privacy.md).

## Status

Implemented declarations; signed integration pending verification. Current verification limits are tracked in [testing](../testing.md).
