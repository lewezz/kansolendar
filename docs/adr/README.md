# Architecture decision records

The records below retain original product decisions and identify later changes.
Their source-status descriptions are not a fresh compile, test, independent-review,
or release attestation. Current behavior is summarized by the [documentation index](../README.md).

| Record | Topic | Current scope |
| --- | --- | --- |
| [ADR-0001](0001-swiftui.md) | Native SwiftUI application | Implemented in source. |
| [ADR-0003](0003-local-only.md) | Local operation without a backend | Implemented product boundary. |
| [ADR-0004](0004-encryption.md) | Authenticated document encryption | Implemented in source; full internal metadata encryption. |
| [ADR-0006](0006-mvvm.md) | Focused presentation, domain, and storage boundaries | Implemented in source and refined by the maintainability pass. |
| [ADR-0007](0007-concurrency.md) | Actor ownership and session generations | Implemented mechanisms; lifecycle integration still pending verification. |
| [ADR-0008](0008-no-sync.md) | No application-managed synchronization | Implemented product boundary. |
| [ADR-0009](0009-no-analytics.md) | No telemetry or remote diagnostics | Implemented product boundary. |
| [ADR-0011](0011-minimal-permissions.md) | Sandbox and selected-file access | Implemented declarations; signed integration pending verification. |
| [ADR-0012](0012-distribution.md) | Single macOS app and pending GitHub delivery | App configuration implemented; delivery decision and artifact verification pending. |

Current document decisions: [ADR-0014](0014-whole-document-vaults.md) and [ADR-0015](0015-current-format-only.md).
