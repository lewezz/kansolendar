# Errors and diagnostics

## Current behavior

Storage uses typed internal errors. KansolendarVault maps them to public VaultError
categories, and the app's VaultError presentation extension supplies user-facing
messages. Operation-specific messages distinguish refused overwrites, unsupported
imports, wrong credentials, corruption, and failed recovery.

The app currently has no OSLog/Logger pipeline, persistent diagnostic log, remote
crash-reporting integration, analytics, or support-bundle exporter. Existing
errors are presented in the UI. Do not describe proposed diagnostic facilities as
implemented.

## Error boundaries

| Category | Current response |
| --- | --- |
| Wrong password or denied authentication | Remain locked; allow retry |
| Missing local key | Recovery-required state; no silent key replacement |
| Invalid/tampered payload | Storage fails closed; clear private presentation data |
| Newer/unsupported format | Reject opening through typed format errors |
| Existing output file | Refuse overwrite |
| Unsupported/duplicate `.ics` data | Reject import before committing a partial batch |
| Restore rollback failure | Report recovery requirement and preserve encrypted candidates |

Detailed database/Keychain status codes are internal. User-visible strings live
in [VaultError+Presentation.swift](../Kansolendar/App/VaultError+Presentation.swift)
and the operation handlers in
[VaultViewModel.swift](../Kansolendar/App/VaultViewModel.swift).

If diagnostics are added later, keep event details, passwords, raw keys, decoded
payloads, full file paths, raw query strings, and arbitrary NSError userInfo out
of logs. Logging should remain a local, explicit facility; adding a remote
pipeline would change product scope.
