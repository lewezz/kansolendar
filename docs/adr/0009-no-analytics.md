# ADR-0009 — Sin analytics, telemetría ni crash uploader

## Context

Los horarios y hábitos son información privada incluso sin títulos. Recopilar uso y diagnósticos ampliaría salidas y dependencias. El producto exige ausencia de telemetría/analytics.

## Decision

No SDKs, eventos de uso, IDs de instalación analíticos ni reportes enviados. Logger propio solo acepta catálogo técnico sin contenido/identificadores privados. Debug usa fixtures; no modo verbose que vuelque datos reales.

## Alternatives

Analytics «anonimizados», opt-in, agregados o solo locales siguen contradiciendo alcance. Crash SDK filtra demasiado contexto por defecto y añade canal externo. Soporte manual futuro podría aceptar informes revisados, nunca DB automática.

## Consequences

Menos visibilidad de fallos en campo; invertir en tests locales y mensajes útiles. Unified Logging/diagnósticos de macOS tienen políticas propias que no podemos deshabilitar globalmente. No presentar OSLog.private como autorización para registrar eventos de calendario.

## Status

Ausencia fijada por requisitos; allowlist propuesta en [logging.md](../logging.md). La auditoría de binario/artefactos forma parte de release.
