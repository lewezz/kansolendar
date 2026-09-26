# Architecture Decision Records

Fecha inicial: 2026-09-25. Los ADRs son registros de decisión y no código. **Fijado por requisitos** se refiere a instrucciones del propietario. **Propuesto** necesita revisión; incluso un ADR con tecnología fijada puede contener detalles propuestos.

| ADR | Asunto | Estado |
|---|---|---|
| [0001](0001-swiftui.md) | SwiftUI nativo | Stack fijado; organización propuesta |
| [0002](0002-sqlite.md) | SQLite frente a SwiftData/ORM | Stack fijado; esquema propuesto |
| [0003](0003-local-only.md) | Offline-only, sin backend ni red | Fijado por requisitos |
| [0004](0004-encryption.md) | Cifrado de payloads | Alcance aceptado 2026-09-25; detalle técnico y riesgos restantes pendientes |
| [0005](0005-keychain.md) | Custodia y recuperación de claves | Autenticación macOS y recuperación separada aceptadas 2026-09-25; validación técnica pendiente |
| [0006](0006-mvvm.md) | MVVM, dominio y repositorios | Patrón fijado; módulos propuestos |
| [0007](0007-concurrency.md) | Swift Concurrency y sesión | Tecnología fijada; aislamiento propuesto |
| [0008](0008-no-sync.md) | Ausencia de sincronización | Fijado por requisitos |
| [0009](0009-no-analytics.md) | Ausencia de analytics/telemetría | Fijado por requisitos |
| [0010](0010-icalendar.md) | Exportación .ics; importación futura | Importación aplazada por el propietario 2026-09-25; exportación propuesta |
| [0011](0011-minimal-permissions.md) | Sandbox y permisos mínimos | Propuesto |
| [0012](0012-distribution.md) | .app y distribución directa | .app fijada; Apple silicon exclusivo decidido 2026-09-25; canal/OS pendientes |

Formato: Context, Decision, Alternatives, Consequences, Status. Al revisar, añadir fecha/decisor y sustituir «Propuesto» solo con aceptación real. Una decisión reemplazada conserva el ADR y enlaza al nuevo; no reescribir historia para fingir que siempre se eligió otra alternativa.
