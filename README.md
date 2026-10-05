<p align="center"><img src="kansolendar-logo.png" alt="Kansolendar logo" width="180"></p>

# Kansolendar

A private, offline calendar for Apple Silicon Macs running macOS 14 or later.
No accounts, servers, app-managed synchronization, analytics, or telemetry.

## Calendar vaults

Create or open a user-named `.kanso` file, then unlock it with its own password.
Each file contains independent calendars and events. New-format files encrypt
all calendar content, IDs, relationships and internal inventory with AES-256-GCM.
The filename, file size, dates and cryptographic header remain visible.

Use a unique password of at least 15 characters. There is no Touch ID unlock,
password reset. You may save the password manually in Apple
Passwords; Kansolendar does not save credentials there automatically.

Vaults lock when closed, when the Mac locks or sleeps, and after inactivity.
The default is 5 minutes; choices are 1, 2, 3, 4, 5, 10, 15 and 30 minutes.
Switching applications does not immediately lock them. Recent-file history is
optional and disabled by default. Multiple files have independent windows/sessions.

Only the current whole-document `.kanso` format is supported. Older formats are
rejected without changing the selected file. Copy a closed `.kanso` yourself when
you need another copy; the app does not manage extra archive formats.

## Features

- Day, week, month and year views; calendar filtering and title search.
- Calendars, colors, all-day/timed events, notes and locations.
- A clear create/open screen with optional recent-file history.
- Passwords concealed by default, with explicit reveal and copy controls.
- Readable text-and-icon toolbar actions and local appearance/privacy preferences.

## Installation from GitHub

When a release is published, download its Kansolendar app archive, extract it,
and move `Kansolendar.app` into Applications. The app uses local ad hoc signing,
without a development provisioning profile or certificate expiry timer. It is
not notarized or identified by Apple through Developer ID.

On first opening, macOS may refuse to launch it. For a download you trust, follow
Apple's per-app process: attempt to open it, then go to **System Settings → Privacy
& Security → Open Anyway** and confirm. Do not disable Gatekeeper globally.
Managed Macs may prohibit this exception. A future macOS version may change
compatibility; absence of a signing expiry is not a permanent compatibility promise.
See [Apple's instructions](https://support.apple.com/en-us/102445).

No GitHub release has been published by this implementation. The artifact still
needs fresh-Mac, quarantined-download and real file-panel integration verification.

## Development

Use Xcode and the shared `Kansolendar` scheme, or run `bash scripts/build.sh`.
The script builds the one Release app at `.build/Latest/Build/Products/Release/Kansolendar.app`
and checks its ad hoc signature, architecture, profiles and entitlements.
It does not install, launch or publish the app.

Run `swift test --package-path Packages/KansolendarKit` for domain/storage tests
and `swift test` for the app-state test harness. When command-line tools are the
selected developer directory, set `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
The app and packages have no remote dependencies.

See the [documentation index](docs/README.md), [vault guide](docs/kanso-vault-files.md),
[security](docs/security.md), and [product specification](kansolendar.md).
