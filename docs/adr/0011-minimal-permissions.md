# ADR-0011 — Sandbox y mínimo acceso al sistema

## Context

Un calendario independiente no necesita leer calendarios Apple ni permisos de contactos/localización. Integraciones del sistema pueden producir copias indirectas y nuevos procesos con acceso al contenido.

## Decision

Sandbox activo con acceso a archivos elegidos y Keychain de identidad propia; sin red ni permisos amplios. Sin notificaciones/recordatorios en MVP, Core Spotlight, Quick Look provider, recientes privados, extensiones ni widgets. Mantener accesibilidad de UI y retirarla al bloquear.

## Alternatives

Desactivar sandbox para simplificar ficheros reduce defensa. Full Disk Access/bookmarks persistentes no están justificados. Avisos con títulos son cómodos pero trasladan datos fuera del control de sesión. Desactivar accesibilidad no impide capturas y perjudica uso legítimo.

## Consequences

Exportación y backup/restore mediante paneles explícitos; importación de calendarios aplazada, sin comandos ni asociación de apertura .ics. Añadir recordatorios exigiría nuevo análisis y autorización de notificaciones al activar, no APNs. No prometer controlar todo Spotlight/Quick Look/clipboard/OS. Release debe auditar entitlements y artefactos reales en todas las versiones soportadas.

## Status

Propuesto, consistente con requisitos; integración y señales por verificar en Q07/Q09. Referencia: [privacy.md](../privacy.md).
