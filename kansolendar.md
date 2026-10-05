# Kansolendar product specification

## Platform and boundaries

A native SwiftUI/AppKit application for Apple Silicon Macs on macOS 14+. One app target, local Core/Storage packages, no remote dependencies, accounts, servers, telemetry or app-managed synchronization. GitHub distribution uses ad hoc signing without a temporary developer profile. Signing has no development expiry timer; future OS compatibility is not guaranteed.

## Documents

Users name and locate independent current-format `.kanso` files. Each has its own password, calendars, event data and key. The app starts with create/open choices, optionally listing recent documents. Obsolete/foreign files are rejected without modification; no external calendar interchange is supported.

AES-256-GCM encrypts the complete internal document. The public header contains bounded password-wrapping parameters, random cryptographic identities and a wrapped data key; filename, length and timestamps remain visible. Password wrapping uses platform PBKDF2-HMAC-SHA256, 600,000 iterations and random salt. Passwords require at least 15 Unicode scalars and at most 1,024 UTF-8 bytes without controls. Losing the password loses access.

## Interaction

The welcome screen gives Create Vault priority, with Open Vault and optional recent-file rows. Document forms use secure fields and clear errors. The post-creation password sheet starts concealed, with explicit Reveal/Hide, Copy Password, Open Passwords and Continue actions. Saving in Apple Passwords is manual; there is no biometric unlocking or reset.

The workspace shows day/week/month/year calendar views, calendars/colors/filtering, event titles/search, all-day/timed events, notes/locations and supported creation/editing/deletion/movement. Recurrence/cancellations are domain/storage values; richer recurrence editing is separate work. Toolbar actions have explicit readable icon/text labels: New Vault, Open Vault, New Event, Lock and Appearance.

## Session and persistence

Files/windows own independent sessions. Lock on close, Mac screen lock/sleep and configured inactivity; default five minutes, choices 1, 2, 3, 4, 5, 10, 15 and 30. Application focus changes alone do not lock. Clear storage/presentation references and reject suspended stale UI publication. Swift does not guarantee perfect memory zeroization.

Candidates are encrypted and saved atomically before publication. Private regular-file handling, stable local writer locks and external-change detection protect cooperative editing. Staging is fsynced; directory synchronization is conditional on access. No absolute power-loss durability, rollback protection or cross-Mac/cloud conflict resolution is claimed.

Users copy/move closed files themselves. Optional history reveals names/paths and defaults off; disabling it erases history. Local preferences are outside the encrypted document. Existing user files are never silently deleted. See [security](docs/security.md), [testing](docs/testing.md), and [distribution](docs/distribution.md).
