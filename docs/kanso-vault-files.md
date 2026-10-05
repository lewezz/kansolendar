# Portable `.kanso` vaults

A `.kanso` file is Kansolendar's own SQLite-based calendar vault. It is not a
KeePass/KDBX file and has no KeePass interoperability.

## Create and open

1. Choose **Create Vault File…** on the vault gate or **Vault → Create New Vault File…**.
2. Choose the file name and directory in the save panel. Existing files are refused.
3. In the new document window, enter and confirm a password of at least 15 characters.
4. Create calendars and events inside that vault.

Use **Open Vault File…** to select an existing document and enter its password.
The project declares the `.kanso` Finder association and routes files into
separate windows. Actual Finder and multi-window behavior on the latest app
build still needs verification.

The app offers to copy a new password and open Apple Passwords. Add the password
there yourself. Retrieve it there with Touch ID or your Mac password, then paste
it into Kansolendar. There is no passkey or automatic Passwords credential save.
Clipboard contents are not automatically cleared.

## What the file contains

Every independently created vault has its own random 256-bit data key, salt,
identifiers, and password wrapper. Calendar/event details are encrypted. SQLite
headers, schema, identifiers, relationships, counts, and sizes remain visible.
The name displayed by the app comes from the file name, not a separately stored
vault-title field.

The exported type is `local.kansolendar.vault`, with extension `.kanso` and MIME
type `application/vnd.kansolendar.vault`. Only the `.kanso` type is registered as
an app document; `.ics` import uses a file panel.

## Portability and coexistence

Lock and close a document before copying, moving, or renaming it. Copies retain
its identity, password wrapper, and contents; copying a file does not generate a
new independent vault identity. Avoid concurrent editing of the same file or its
copies when expecting a single authoritative history.

Each document has a separate app-level unlock session. The local Application
Support vault is a separate store; creating a portable file does not migrate or
delete it. Moving a document to another Mac does not depend on the original
Mac's Keychain, but compatible app installation still needs separate validation.

See [key management](key-management.md), [backups](backups.md), and
[security](security.md) for recovery and protection limits.
