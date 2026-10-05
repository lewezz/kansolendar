# ADR-0015: One current encrypted document format

The user explicitly removed all obsolete-format compatibility, legacy conversion, separate archive/recovery capabilities and calendar interchange. Only the current whole-document `.kanso` format is created/opened. Existing user files are never deleted as part of source cleanup.

The app uses extension-aware file selection followed by authenticated storage validation, concealed post-creation passwords with explicit reveal/copy, a native welcome layout and readable toolbar actions. Whole-document encoding, key wrapping and session locking remain compatible with current files.

This reduces parsers and persistence branches. It does not remove the need for strong passwords, safe file handling or verification, and does not guarantee security against a compromised unlocked Mac. Older-format users cannot open those files in this version.
