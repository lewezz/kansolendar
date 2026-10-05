<p align="center"><img src="kansolendar-logo.png" alt="Kansolendar logo" width="180"></p>

# Kansolendar - Nobody needs to know your plans

A private, offline calendar for Apple Silicon Macs running macOS 14 or later.
No accounts, servers, app-managed synchronization, analytics, or telemetry.

## Installation from GitHub

Requires an **Apple Silicon Mac (M1 or later) with macOS 14 or later**. This build
supports arm64; it does not run on Intel Macs.

1. Open this repository's **Releases** page and download the
   `kansolendar-N.Nv.zip` asset. Do not download the source-code ZIP.
2. Double-click the ZIP to extract **Kansolendar.app**.
3. Drag **Kansolendar.app** into your **Applications** folder.
4. Open Kansolendar from Applications.

### First opening: allow this app in macOS

macOS may block the first launch with a message that the developer cannot be
verified or Apple cannot check the app for malicious software. Kansolendar uses
**ad hoc signing**: it is not signed with an Apple Developer ID certificate and
has not been notarized by Apple. Gatekeeper therefore cannot establish Apple's
usual developer/notarization trust for this download.

If you trust this repository and downloaded its release asset:

1. Attempt to open **Kansolendar.app** from Applications. Dismiss the warning
   without moving the app to the Trash.
2. Open **System Settings → Privacy & Security** and scroll to the **Security** section.
3. Find the message about Kansolendar and click **Open Anyway**.
4. Authenticate if macOS asks, then confirm **Open** in the next dialog.

macOS records an exception for this app. You can then open it normally from
Applications; a new version may require approval again. See
[Apple's first-opening instructions](https://support.apple.com/en-us/102445).

Do not disable Gatekeeper globally. If **Open Anyway** is unavailable on a
managed Mac, contact its administrator. A warning that the app is damaged or
will harm your computer is a different condition: do not bypass it; download
again from the repository's release and report the issue if it persists.

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
- Readable text-and-icon toolbar actions and local appearance/privacy preferences, including ten shared font choices: System, Serif, Rounded, Monospaced, Helvetica Neue, Arial, Avenir, Georgia, Times New Roman and Verdana.

### Does the app expire?

This build has **no signing expiration date**: it uses no Apple signing
certificate or temporary development provisioning profile. It does not require
periodic renewal or an Apple Developer subscription. Future macOS compatibility
and security-policy changes remain separate from signing expiration.

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
