# Calendar vault files

The welcome screen offers Create Vault and Open Vault. Choose a name/location for a new `.kanso`, then set and confirm its password. Independently created files have independent contents, keys and sessions. Each may contain multiple calendars. Creating refuses an existing destination.

Open selects files by their `.kanso` extension, including uppercase extensions, rather than requiring registered Finder metadata. Storage then validates the actual current encrypted container; renaming an arbitrary file does not make it a vault. Obsolete or foreign formats are rejected without modification. There is no legacy converter or external calendar interchange.

Passwords are concealed initially in both entry fields and the post-creation sheet. You may reveal or copy the chosen password, open Apple Passwords manually, or continue. Forgotten passwords cannot be reset.

Copy or move a closed file yourself. A copy retains its original contents, identity and password. The app does not synchronize or merge copies; user-selected cloud folders are the user's responsibility. Writer locks are local and content digests reject external modifications before saving, without providing cross-Mac locking or rollback detection.

Recent-file history is opt-in and initially disabled; disabling it clears history. Files lock on close, Mac lock/sleep and inactivity, defaulting to five minutes with 1, 2, 3, 4, 5, 10, 15 and 30 choices. Application switching alone does not lock. See [privacy](privacy.md), [security](security.md), and [testing](testing.md).
