# Security

Current `.kanso` documents encrypt all internal calendar/event values, relationships and inventory with AES-256-GCM. The framing/header is authenticated exactly; malformed sizes and parameters are bounded before password derivation. Password wrapping uses platform PBKDF2-HMAC-SHA256 with 600,000 iterations and random salt. PBKDF2 is not memory-hard: use long unique passwords.

Only filenames, file properties and cryptographic parameters remain public. Memory, screen and intentional clipboard copying are outside at-rest protection. Password presentation starts concealed; revealing is explicit. Copies are current-host-only and expire after 30 seconds if unchanged while the process is running. Clipboard managers/local processes may still access them.

The app has no biometric path, password reset or external calendar interchange. Only the current document format is supported. Dropping older parsers reduces attack surface; it is not proof of absolute safety. Unsupported/corrupt files are rejected without modifying them.

Encrypted-only staging and atomic replacement avoid plaintext persistence. Failed/ambiguous writes lock storage and clear UI. Writer ownership is cooperative/local; external changes are refused before replacement. Directory fsync may be unavailable under a selected-file grant, so sudden power-loss durability is not guaranteed.

The sandbox permits user-selected files and app-scoped bookmarks, without network privileges. Ad hoc signing avoids an expiring developer profile but lacks Apple publisher identification/notarization. See [threat model](threat-model.md), [privacy](privacy.md) and [testing](testing.md).
