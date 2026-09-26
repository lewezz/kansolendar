# Kansolendar — arquitectura y documentación

Fecha: 25 de septiembre de 2026. Estado: **propuesta completa para revisión; no autoriza implementación**.

Revisión parcial aceptada por el propietario: cifrado del contenido con metadatos visibles, autenticación de macOS y archivo de recuperación separado. Además, importación de calendarios aplazada y soporte exclusivo Apple silicon, sin Intel. Véanse Q01/Q03/Q04/Q05/Q06 en [registro de decisiones](open-questions.md). Permanecen pendientes macOS/Xcode/SDK, validación técnica, otras decisiones y autorización de implementación.

El repositorio de partida contiene únicamente [los requisitos](../kansolendar.md). No hay aplicación, proyecto Xcode, esquema ejecutable ni pruebas que auditar. Esta entrega añade exclusivamente documentación. Las políticas descritas son requisitos de la futura implementación, no garantías verificadas de un producto existente.

## Lectura recomendada

1. [Resumen ejecutivo](executive-summary.md) y [MVP](mvp.md).
2. [Modelo de amenazas](threat-model.md), elaborado como fundamento de las decisiones.
3. [Arquitectura](architecture.md) y [decisiones pendientes](open-questions.md).
4. [Dominio](data-model.md), [SQLite](database.md), [seguridad](security.md) y [claves](key-management.md).
5. [Privacidad y permisos](privacy.md), [intercambio .ics](icalendar.md), [backups](backups.md) y [errores/logs](logging.md).
6. [Testing](testing.md), [distribución](distribution.md), [roadmap](roadmap.md) y [ADRs](adr/README.md).

## Convenciones y precedencia

- **Fijado por requisitos**: stack y exclusiones indicados por el propietario del producto.
- **Propuesto**: elección de esta arquitectura, pendiente de revisión. No equivale a aceptación del usuario.
- **Gate**: condición que debe resolverse antes de iniciar la fase indicada.
- **Fuera del MVP**: no crear permisos, tablas, servicios ni dependencias para esa función ahora.
- **Límite**: propiedad que esta aplicación no puede garantizar frente al sistema o un atacante.

Los requisitos prevalecen. `open-questions.md` identifica conflictos, sin alterar el stack. Los documentos especializados son la referencia de cada contrato; los ADRs registran el motivo y el estado. Si cambia cifrado, claves o representación temporal, deben revisarse conjuntamente dominio, esquema, backups, pruebas y ADRs.

## Respuestas rápidas

| Pregunta | Respuesta propuesta | Detalle |
|---|---|---|
| ¿Estructura? | App SwiftUI/MVVM, núcleo de dominio, adaptadores locales | [Arquitectura](architecture.md) |
| ¿Dónde están los datos? | Application Support del contenedor sandbox, SQLite | [Base de datos](database.md) |
| ¿Cifrado? | Payloads sensibles con AES-256-GCM antes de SQLite; no cifrado integral del archivo | [Seguridad](security.md) |
| ¿Claves? | Una clave aleatoria por bóveda en Keychain local; recuperación manual separada | [Claves](key-management.md) |
| ¿Quién lee contenido? | El proceso autorizado mientras está desbloqueado; no protección absoluta ante malware privilegiado | [Amenazas](threat-model.md) |
| ¿Permisos? | Sandbox, archivos seleccionados y acceso Keychain de la propia identidad | [Privacidad](privacy.md) |
| ¿Internet? | Sin funciones ni entitlements de red; el sistema operativo conserva sus propias capacidades | [Privacidad](privacy.md) |
| ¿DB copiada? | Contenido ilegible sin clave; estructura, tamaños y relaciones visibles | [Seguridad](security.md) |
| ¿Backups? | Snapshot consistente de SQLite con payloads cifrados; clave separada obligatoria para portabilidad | [Backups](backups.md) |
| ¿Migraciones? | Versionadas, transaccionales, con copia previa y sin downgrade automático | [Base de datos](database.md) |
| ¿Eventos/recurrencias? | Instantes, fechas civiles y zona explícitos; expansión acotada | [Dominio](data-model.md) |
| ¿.ics? | Exportación limitada; importación aplazada y documentada solo como referencia futura | [.ics](icalendar.md) |
| ¿Verificación? | Pruebas de datos, seguridad y privacidad sobre binario firmado | [Testing](testing.md) |
| ¿Distribución? | Xcode → .app firmada y notarizada → DMG opcional | [Distribución](distribution.md) |

Las referencias técnicas oficiales se enlazan junto a las afirmaciones relevantes. Su consulta se realizó para diseñar esta documentación; **no implica que la aplicación vaya a acceder a esas URL**. La política concreta de Kansolendar se distingue de las capacidades generales de esas APIs.
