# ADR-0004 — Cifrar payloads sensibles antes de SQLite

## Context

Copiar DB o backups no debe revelar contenido sin la clave. SQLite del sistema no tiene cifrado integral de páginas; CryptoKit no es un codec SQLite. Cero dependencias y no criptografía propia impiden fingir esa capacidad. Ver [análisis de alternativas y fuentes](../security.md).

## Decision

AES-256-GCM CryptoKit por payload, con DEK aleatoria por bóveda, nonce fresco por sellado y AAD ligada a versión/identidad/tipo/padre. Cifrar también horarios, zonas, UID, recurrencias y preferencias privadas. Solo SQLite estructural y relaciones opacas en claro. Índices de búsqueda en RAM durante sesión. Envelope v1 se congela como `KNSL | version | nonce | ciphertext | tag`, con formato exacto y vector en [security.md](../security.md).

## Alternatives

Solo FileVault no protege copia desde sesión. SQLCipher/SEE requieren excepción al stack. Snapshot completo cifrado exige gestionar durabilidad de archivo y RAM. Volumen cifrado complica UX/sandbox. VFS/codec propio se rechaza por seguridad y complejidad.

## Consequences

No llamar al resultado «DB completamente cifrada». Conteos, tamaños, relaciones y cambios quedan visibles. Búsquedas requieren descifrado/índice de sesión. AEAD por fila no detecta toda eliminación ni replay de copia válida. Nunca persistir plaintext en índices/staging; revisar binding y artefactos. No se permite almacenar datos reales hasta validar Keychain firmado, DB/backups, integración y revisión independiente.

## Status

**Alcance del cifrado aceptado por el propietario el 2026-09-25**, al responder «1. si»: contenido cifrado con estructura, conteos y tamaños visibles. El plan de implementación de alto riesgo fue aprobado el 2026-09-26. El codec y vector v1 están implementados; siguen pendientes Q02/Q08, revisión independiente, validación Keychain y persistencia integral. No se infiere aceptación del límite antirrollback. Referencia: [security.md](../security.md).
