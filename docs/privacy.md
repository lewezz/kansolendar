# Privacy and permissions

## App access

The [entitlements file](../Kansolendar/Kansolendar.entitlements) declares the app
sandbox, read/write access to user-selected files, and the app's Keychain access
group. It does not declare client/server networking, system-calendar access,
contacts, location, notifications, or broad disk access.

File panels select portable documents, backups, recovery kits, and `.ics` files.
The model keeps security-scoped access for an open portable document and balances
claims on close. File selection can still choose a directory managed by a cloud
provider; Kansolendar does not perform or control that provider's synchronization.

## Data outside the vault

Appearance and accent preferences use local AppStorage/UserDefaults. Password
copies use the system clipboard and are not automatically cleared. Recovery kits
are plaintext key-bearing files. iCalendar exports are plaintext. File names are
visible in panels and the workspace; encrypting payloads does not hide names,
SQLite metadata, or operating-system file history.

Decrypted calendar/event values exist in the unlocked process and are exposed to
ordinary UI rendering and accessibility. Standard macOS screen capture, filesystem
backups, clipboard management, and account access are not controlled by the app.
Kansolendar does not implement telemetry, remote crash submission, cloud services,
EventKit integration, Spotlight providers, Quick Look extensions, or widgets.

## Locking

Manual lock clears presentation data and invalidates the key session. Portable
window-close handling clears fields and lists, rejects stale UI results, and
releases file access. There is no idle timeout or automatic background/sleep/
session-change lock observer in the current source. No app-support-window close
lock hook is explicitly implemented by closeDocument, which is portable-only.

These protections do not isolate an unlocked process from a compromised account
or operating system. Current signed/sandbox runtime behavior needs verification;
source entitlements alone are not a verified-artifact privacy audit. See
[security](security.md), [threat model](threat-model.md), and [testing](testing.md).
