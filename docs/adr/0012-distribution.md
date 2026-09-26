# ADR-0012 — .app firmada y distribución directa inicial

## Context

El usuario quiere instalar Kansolendar en /Applications y abrirla normalmente. Un binario de depuración o ejecutable CLI no satisface esa experiencia. Firma también afecta continuidad de Keychain.

## Decision

Xcode produce .app autónoma exclusivamente arm64 para Apple silicon, sin soporte Intel ni Universal 2. Proponer distribución directa Developer ID, hardened runtime, sandbox, notarización y ticket adjunto; DMG opcional. Actualizaciones manuales. Identidad de producto estable y test/dev separados. SPM solo local.

## Alternatives

Build ad hoc sirve a desarrollo pero no es canal final. Mac App Store es posibilidad futura con revisión de firma/privacidad. Instalador privilegiado, daemon o runtime descargado no son necesarios. Updater remoto contradice ausencia de red.

## Consequences

Publicación requiere recursos/cuenta de desarrollador y conectividad con Apple; ejecución del calendario no. Probar Gatekeeper/offline con artefacto final, no solo desde Xcode. Hardware queda fijado a Apple silicon. El propietario aprobó macOS 14 como mínimo de implementación/MVP el 2026-09-26; revisar soporte antes de distribución. QA y comprobación de arquitectura del artefacto se centran en arm64.

## Status

.app y herramientas fijadas. **Apple silicon exclusivamente por decisión del propietario el 2026-09-25** («no soporte para macs intel»); sustituye la posibilidad inicial de Intel/Universal 2. macOS 14 está aprobado como mínimo de implementación/MVP el 2026-09-26. Build comprobado con Xcode 27/macOS 27 SDK; toolchain fijado de release y canal de distribución siguen pendientes, Q06/Q11. Ver [distribution.md](../distribution.md).
