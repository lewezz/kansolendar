# Verification status

The current correction slice removes obsolete persistence/interchange suites together with their unsupported implementations. Its retained domain/encryption/persistence tests and app-state/file-selection tests are recorded in the active implementation workspace.

The latest recorded focused run passed 17 storage tests, 27 core tests and nine app-state tests. Coverage includes encryption/tampering/headers, domain validation/recurrence, current-file reopen/writer exclusion/external-change rejection, foreign-format refusal without source changes, independent sessions, queued creation locks, password concealment/reset, extension-based open-panel filtering, lifecycle callbacks and clipboard expiry.

Actual SwiftUI app sources passed a separate full-source typecheck. A temporary test helper rendered the production welcome views in light and dark appearance, the concealed and revealed password view, and the calendar toolbar. Actual native open-panel delegate callbacks enabled `.kanso` and `.KANSO` fixtures and disabled text/ICS fixtures. A synthetic current-format file created before the correction slice reopened without changing its bytes; invalid reauthentication cleared its unlocked session. No new distributable application, installation or release is required for these source checks. Subsequent user-requested Release builds include the correction slice. Local release preparation additionally verifies the extracted ZIP signature and its SHA-256 checksum; this does not establish behavior after a browser download on another Mac.

Injected lifecycle events do not prove real OS notification delivery; delegate filter checks do not prove all desktop panel interactions. The native panel screenshot cannot capture its remote content; selection evidence comes from its actual delegate callbacks. These checks do not claim manual clicks on every control, full keyboard interaction, or a second-Mac installation. A separate supported Mac and quarantined-download/update behavior are not established by local tests.

## Commands

```sh
bash scripts/test.sh
```

The root package compiles actual app-state and file-panel sources as a library test harness. Use synthetic data only. Future requested artifacts use the existing single-app build script; do not install or publish implicitly.
