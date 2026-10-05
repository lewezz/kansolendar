# Kansolendar product specification

Updated: 2026-10-05. This document describes the current implementation and product
scope. It replaces the original documentation-only phase brief. Source presence
is distinguished from verification in [testing status](docs/testing.md).

## Purpose

Provide a native macOS calendar whose data is owned locally by the user. Calendar
use must not require an account, backend, network connection, subscription, or
analytics service. The deliverable is a conventional macOS `.app`.

## Technology and boundaries

| Area | Current implementation |
| --- | --- |
| Language and UI | Swift 6 and SwiftUI, with focused AppKit file panels |
| Domain | Validated dates, events, calendars, recurrence, and search in KansolendarCore |
| Storage | System SQLite and encrypted payloads in KansolendarStorage |
| Cryptography | CryptoKit AES-GCM; CommonCrypto PBKDF2 for password wrapping |
| Local key custody | Security/Keychain with user-presence access control |
| Presentation | MainActor observable view model per window |
| Concurrency | Vault actors and synchronous SQLite transaction bodies |
| Package management | One local Swift package, no remote dependencies |
| Platform configuration | macOS 14 minimum, arm64 only |
| Tests | Swift Testing package suites; current refactors not rerun |

No web runtime, SwiftData, ORM, remote service, or alternative application variant
is part of the implementation. See [architecture](docs/architecture.md).

## Vault ownership

A user chooses each portable vault's file name and location. A `.kanso` file has
its own random data-encryption key, random salt, and password-wrapped key record.
Multiple calendars live inside that file. Independent files do not share their
passwords or unlocked sessions.

Passwords are user-chosen, confirmed, at least 15 Unicode scalars, at most 1,024
UTF-8 bytes, and contain no control characters. The app suggests manually saving
them in Apple Passwords. It does not register passkeys or directly store Passwords
credentials.

The local Application Support vault has a separate Keychain backend. Creating a
portable vault does not automatically convert or delete that store. See
[vault files](docs/kanso-vault-files.md) and [key management](docs/key-management.md).

## Calendar behavior

The app includes day/week/month/year views, calendar filtering, title search,
calendar creation/deletion, and event creation/editing/deletion/movement. Events
can include notes and a location. All-day dates use an exclusive end; timed
values distinguish UTC instants and zoned local times.

Core and Storage support bounded recurring series and occurrence cancellations.
The app has no recurrence-rule editor. Recurring series cannot be dragged, and
safe series/occurrence editing still needs implementation and verification.

## Files and recovery

- `.kanso`: custom SQLite document containing encrypted payloads and its wrapped key.
- `.kansobackup`: encrypted-payload SQLite snapshot, validated before export.
- Recovery kit: separate plaintext key-bearing text file; Base64 is not encryption.
- `.ics`: plaintext interchange using a deliberately limited profile.

Restoration validates the backup and matching kit, retains a safety snapshot,
and attempts rollback on replacement failure. A populated portable vault with
unrelated identity cannot be replaced. The recovery path into a new empty vault
requires a new password. See [backups](docs/backups.md) for the exact limits.

## Privacy and permissions

The app sandbox declares user-selected file read/write access and the app's
Keychain group. It has no network, EventKit, contacts, location, notification, or
broad disk-access entitlement. Appearance settings are stored outside the vault.

Payload encryption does not hide database metadata or prove database freshness.
An unlocked process holds decrypted values. Clipboard copies, plaintext exports,
and locations selected in cloud-backed folders are outside encrypted-vault
protection. See [security](docs/security.md) and [privacy](docs/privacy.md).

## Current limits and unfinished verification

Manual locking and portable-document close handling exist. Background, sleep,
session-change, and idle-timeout locking are not implemented. The latest source
has not been compiled or tested in this revision series because the user
prohibited additional builds unless requested.

Finder association, multiple windows, signed Keychain behavior, restore/lock
interleaving, and calendar boundary handling still require verification. GitHub
is the requested distribution channel; publishing, packaging, update delivery,
and installed-app launch validation are not established in the repository.

Notifications, attachments, attendees, system-calendar integration, widgets,
cloud synchronization, analytics, automatic updates, and full iCalendar support
are outside the current implementation. See [open work](docs/open-questions.md).
