# Resumen ejecutivo

Kansolendar es viable como aplicación macOS nativa, local y sin servicios externos dentro del stack indicado. El propietario ha aceptado el 2026-09-25 esta distinción: **SQLite del sistema no ofrece cifrado integral; el diseño cifra todo el contenido sensible con CryptoKit dentro de SQLite y deja visibles estructura y ciertos metadatos**.

## Arquitectura propuesta

Un target SwiftUI/MVVM y un paquete SPM local con dos módulos: Core (dominio, reglas y servicios) y Storage (repositorios, SQLite, CryptoKit/Keychain y backups). Una bóveda, un Storage actor, UI aislada en MainActor. Sin procesos auxiliares, ORM, EventKit, dependencias externas ni capa de red. Datos en Application Support del contenedor sandbox, no en Documents ni en directorios sincronizados elegidos por la app.

Una DEK aleatoria de 256 bits por bóveda, custodiada en Keychain local con presencia de usuario. Payloads AES-GCM incluyen horarios, zonas, reglas y UID, además de títulos/notas. La clave se conserva en RAM solo durante sesión abierta. Búsqueda e índice temporal en memoria; se vacían al bloquear. Copiar la DB sin clave no permite leer esos campos, pero revela conteos, tamaños y relaciones.

Backups consistentes guardan los mismos payloads cifrados. Restaurar en otro Mac requiere un kit de recuperación separado que contiene el secreto: guardarlo junto al backup anula esa separación. No hay recuperación del desarrollador. Exportar .ics produce deliberadamente un archivo legible y no sustituye al backup.

## Decisiones fijadas y propuestas

Fijadas por los requisitos: Swift 6, SwiftUI, SQLite sin SwiftData/ORM inicial, CryptoKit/Security, Swift Concurrency, Swift Testing con XCTest cuando proceda, Xcode/SPM e iCalendar; cero backend, red, sincronización, cuentas y analytics.

Aceptadas por el propietario el 2026-09-25: cifrado del contenido con metadatos visibles, desbloqueo mediante macOS sin contraseña independiente y archivo de recuperación separado, con sus riesgos de custodia/pérdida explicados. También ha decidido aplazar la importación de calendarios y admitir exclusivamente Apple silicon (arm64), sin Intel. Pendientes: validación de DP Keychain/ACL y restauración, detalles de arquitectura/exportación y versiones macOS/Xcode/SDK. Los ADRs distinguen decisiones impuestas, aceptaciones y propuestas aún no aprobadas.

## Riesgos principales

1. Cifrado por payload no oculta metadatos ni detecta toda eliminación/replay de filas; búsquedas tienen coste en RAM y desbloqueo O(N).
2. Perder Keychain y recuperación implica perder datos. Obtener backup y kit permite descifrarlos.
3. Malware privilegiado, captura y memoria de una sesión abierta exceden garantías de la app. No hay zeroización ni borrado forense absoluto.
4. Recurrencias, DST y exportación .ics son áreas de alta complejidad. El MVP no transforma silenciosamente una serie; la importación se aplaza para reducir superficie y esfuerzo.
5. Offline-only describe el comportamiento de Kansolendar; no impide actividad propia del OS ni que el usuario copie/exporte a un destino sincronizado.

## MVP y roadmap

Apple silicon exclusivamente. Mes/lista, calendarios simples, CRUD, eventos all-day/zoned/UTC, recurrencia limitada, búsqueda, bloqueo, cifrado, backup/restore y exportación .ics limitada. Sin importación de calendarios, Intel, recordatorios, asistentes, adjuntos, reglas avanzadas, sincronización ni integraciones de proveedores.

Orden: revisión documental → skeleton/viabilidad de seguridad → dominio temporal y almacenamiento cifrado con recuperación → UI → exportación .ics → auditoría → .app arm64 firmada/notarizada y DMG opcional. Pruebas y privacidad acompañan todas las fases.

## Decisiones pendientes y siguiente paso

Q01 y las elecciones de producto de Q03/Q04 están aceptadas; faltan sus verificaciones técnicas. Q05 aplaza importación y Q06 fija hardware Apple silicon; queda seleccionar macOS mínimo y Xcode/SDK. El [registro completo](open-questions.md) conserva los demás riesgos y gates. Después de completar la revisión, autorizar un skeleton y pruebas de viabilidad con fixtures; la aceptación parcial no inicia implementación.

Esta fase termina con documentación para revisión. No se han creado vistas, modelos Swift, tablas de producción, criptografía, migraciones ni tests de implementación.
