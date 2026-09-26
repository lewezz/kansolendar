# ADR-0003 — Sin backend y sin funciones de red

## Context

La privacidad debe depender del diseño y no de promesas de un servidor. La aplicación debe funcionar instalada, sin cuenta, conectividad ni servicio de disponibilidad externo.

## Decision

Toda la lógica y datos en el Mac. Sin backend, endpoints, Network.framework, red saliente/entrante, servidor localhost, servicios web, actualizador ni comprobación remota de licencia. Sandbox sin entitlements client/server. Auditar delegaciones de red mediante otras apps/servicios.

## Alternatives

Backend «privado», cifrado extremo a extremo con servidor y sincronización opt-in siguen introduciendo servicios y quedan fuera del producto. Un servidor local añade procesos/superficie sin necesidad.

## Consequences

Actualizaciones manuales; recursos y ayuda locales. Notarización/publicación pueden necesitar Internet en entorno del desarrollador. El OS puede realizar su propio networking y usuarios pueden exportar a ubicaciones sincronizadas: no se promete controlar el Mac completo. Las pruebas deben comprobar ausencia de intentos, no solo funcionamiento desconectado.

## Status

Fijado por requisitos; mecanismos de verificación propuestos. Ver [privacy.md](../privacy.md). No hay backend «futuro» reservado.
