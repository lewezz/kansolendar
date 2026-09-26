# ADR-0007 — Swift Concurrency y acceso de sesión aislado

## Context

La UI debe responder mientras se procesa SQLite o .ics. Swift 6 ofrece aislamiento/Sendable, pero la suspensión y cancelación todavía pueden producir carreras lógicas con bloqueo de bóveda.

## Decision

MainActor para presentación; un Storage actor dueño de conexión, clave y cachés. Valores Sendable en fronteras. Servicios async/await y tareas cancelables ligadas a generación de sesión. No await dentro de transacción. Al bloquear, ocultar UI, invalidar operaciones y vaciar consumidores; callbacks antiguos no repueblan vistas.

## Alternatives

Todo en MainActor bloquea UI. Actors por entidad complican atomicidad. GCD compartido manual y @unchecked Sendable generalizado eliminan comprobaciones útiles. Múltiples conexiones no se justifican inicialmente.

## Consequences

Actor no garantiza hilo fijo ni convierte SQLite en API no bloqueante. Medir llamadas/lotes; executor dedicado solo si hace falta. Revalidar estado tras suspensión. La cancelación es cooperativa: no cerrar handle ni revocar memoria mientras código C sigue usándola. Swift no demuestra ausencia de todos los races de negocio.

## Status

Tecnología fijada; estrategia de aislamiento/bloqueo propuesta, Q07. Referencia: [arquitectura](../architecture.md) y [pruebas](../testing.md).
