# ADR-0008 — Sin sincronización ni cuentas

## Context

El producto definido debe ser independiente, local y sin cuentas. Sincronización introduce identidades, conflictos, credenciales, transporte y disponibilidad externa, aunque sea opt-in.

## Decision

No CloudKit/iCloud, CalDAV, Google, Outlook, cuentas, replicación ni sincronización LAN. .ics es exportación manual en el MVP; su importación está aplazada por decisión del propietario. Backup/restore es recuperación deliberada, no merge continuo. No tokens, campos serverID, tombstones de sync ni capa de adaptadores futura.

## Alternatives

Sync E2E o solo LAN preservaría parte de confidencialidad pero viola alcance y añade problemas de convergencia. Usar carpeta sincronizada como DB activa no es sustituto seguro y se rechaza.

## Consequences

Cambios en dos Macs no se combinan automáticamente. UID sirve a intercambio limitado, no reconciliación distribuida. Restaurar copia puede reemplazar datos posteriores mediante elección explícita. El usuario conserva control de sus exportaciones, incluyendo copias externas, fuera de garantías de la app.

## Status

Fijado por requisitos. Reconsiderarlo sería redefinir producto, no activar una opción escondida. Ver [MVP](../mvp.md).
