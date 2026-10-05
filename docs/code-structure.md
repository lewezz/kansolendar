# Code structure

| Responsibility | Source |
| --- | --- |
| App scenes and document windows | `KansolendarApp.swift` |
| Welcome, password gate and concealed password sheet | `RootView.swift` |
| Calendar workspace and readable action bar | `CalendarWorkspaceView.swift` |
| Current-format file panels and extension selection | `VaultFilePanel.swift` |
| Session/presentation ownership and CRUD | `VaultViewModel.swift` |
| Idle/system/close locks, optional recent bookmarks and clipboard expiry | `VaultLifecycle.swift` |
| Domain validation, time and recurrence | `KansolendarCore` |
| Password-only public storage boundary | `KansolendarVault.swift` |
| Encrypted document state and domain codec | `KansoDocument.swift`, `VaultPayloadCodec.swift` |
| Authenticated file framing and password wrapping | `KansoFileEnvelope.swift`, `PasswordKeyWrapper.swift` |
| Serialized encrypted saves and private file operations | `PortableVaultDatabase.swift`, `KansoFileLease.swift`, `PrivateFileIO.swift` |

The root Swift package compiles the actual app state and file panel for regression tests; it is a library harness, not another application. Keep keys and serialized private data behind storage boundaries. Prefer focused changes in the owning layer. See [architecture](architecture.md).
