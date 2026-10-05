# Privacy

Kansolendar implements no accounts, backend, synchronization, telemetry, analytics,
remote crash reporting or data collection. Its sandbox has no network entitlement.
User-selected cloud folders are the user's choice; the app neither uploads nor
merges their contents. macOS/cloud providers may still perform their own operations.

New vaults encrypt calendar details and internal metadata as one authenticated
document. External filenames, sizes, dates and cryptographic parameters remain
visible. Plaintext exists in an unlocked session and intentional clipboard copies.
Manual copying to Apple Passwords uses the clipboard; it is current-host-only and clears after 30 seconds if unchanged.

Preferences are outside the vault. Recent-file bookmarks are optional and initially
disabled; turning them off clears history. Operational per-path lock markers use
hashes in private Application Support, contain no key/content, and are not a
recent-files list. Existing user files are not silently deleted.

No protection is promised against a compromised Mac or observation of an unlocked
process/screen. See [security](security.md) and [testing](testing.md).
