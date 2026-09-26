# Persistencia SQLite: diseño inicial

Estado: el esquema v1 y su migración inicial están implementados en `SQLiteVaultDatabase`; el actor conserva conexión, sesión de clave y operaciones de repositorio. `KansolendarVault` ofrece a la app estado y CRUD con errores de dominio saneados. DTOs de dominio se serializan y sellan antes de SQL. Las pruebas usan datos sintéticos y Keychain inyectado: el flujo real de Keychain aún no se ha validado con firma de desarrollo y no se debe guardar información personal hasta cerrar ese gate. Backup/restore y tests UI siguen pendientes. SQLite del sistema se enlaza mediante un system-library target local; sin ORM, sin SwiftData, sin dependencia de terceros ni extensión cargable.

## Ubicación y exposición

Resolver Application Support mediante FileManager dentro del sandbox; ruta conceptual:

`~/Library/Containers/<bundle-id>/Data/Library/Application Support/Kansolendar/vault.sqlite`

No construir a mano rutas de home ni guardar en Documents, iCloud Drive, /Applications o junto al ejecutable. Directorio privado con permisos propuestos 0700 y archivos 0600; no son aislamiento entre procesos del mismo usuario. No selector de ubicación de bóveda en MVP; no DB activa en volumen remoto. Los paneles solo sirven para intercambio/copias.

El archivo **es SQLite legible estructuralmente**. SQL nunca recibe título, nota, UID, fechas ni zona en claro: recibe BLOBs ya sellados. Cabecera, esquema, IDs aleatorios, relaciones, versiones y tamaños quedan visibles. No llamar a esto «SQLite completamente cifrada».

## ER textual

```text
vault_meta (exactamente 1)
  vault_id, active_key_id, versiones, control sellado
          (una bóveda contiene)
                   |
             calendars 1 -------- N events 1 -------- N event_exceptions
                PK id               PK id                 PK id
                                    FK calendar_id        FK event_id

Cada fila de negocio tiene envelope AEAD; no tabla por ocurrencia.
Reminder/Attendee/Tag/Attachment: sin tablas en MVP.
```

## Convenciones comunes

UUID: BLOB de 16 bytes, representación estable. Enteros: INTEGER con signo (64 bits). Texto sensible: UTF-8 **dentro** de payload cifrado, no TEXT de SQLite. `payload_envelope` es BLOB NOT NULL con layout fijo `magic[4] | version[1] | nonce[12] | ciphertext[n] | tag[16]`, máximo 131105 bytes según [security.md](security.md). Cada columna obligatoria se define NOT NULL. Las PK BLOB deben declarar NOT NULL explícito; no confiar en peculiaridades históricas de SQLite.

Tipos y longitudes se verifican con constraints; usar STRICT si está disponible en todas las versiones mínimas admitidas, o constraints de `typeof` equivalentes. La versión de SQLite del SDK no se asume constante entre macOS: probar capacidades y no depender de extensiones opcionales. No usar JSON1 ni FTS. El target `CSQLite` solo incluye `<sqlite3.h>` del SDK y enlaza `libsqlite3`; el proyecto no añade wrapper/ORM ni descarga código.

### vault_meta

| Columna | Tipo | Clave/constraint | Significado |
|---|---|---|---|
| singleton | INTEGER | PK, valor único 1 | Una fila; existencia validada también por aplicación |
| vault_id | BLOB(16) | UNIQUE, NOT NULL | Identidad original conservada al restaurar |
| schema_version | INTEGER | positivo | Estructura física, sincronizada con user_version |
| active_key_id | BLOB(16) | NOT NULL | Identificador público de la clave de esta bóveda |
| control_envelope | BLOB | NOT NULL, máximo 131105 bytes | Identidad/versión y preferencias privadas selladas; envelope v1 |

El control interior contiene marcador de formato, vault_id, key_id y versión de payload; permite comprobar clave/identidad incluso con bóveda vacía. El plaintext máximo es 131072 bytes; preferencias mayores se rechazan, no amplían arbitrariamente este límite. No es inventario autenticado de todas las filas ni detección de rollback. Los campos del encabezado solo orientan lectura; antes de autenticar son entrada no confiable. Control de esquema y límites antes de abrir payloads.

### calendars

| Columna | Tipo | Constraint |
|---|---|---|
| id | BLOB(16) | PK, NOT NULL |
| payload_envelope | BLOB | NOT NULL, máximo 131105 bytes |

Payload: versión de contenido, nombre, color, orden, zona predeterminada, revisión y fechas de creación/modificación. Ninguno de estos datos necesita índice en disco.

### events

| Columna | Tipo | Constraint |
|---|---|---|
| id | BLOB(16) | PK, NOT NULL |
| calendar_id | BLOB(16) | FK calendars.id, NOT NULL, DELETE RESTRICT |
| payload_envelope | BLOB | NOT NULL, máximo 131105 bytes |

Payload: versión, UID, título/notas/ubicación, variante temporal completa, recurrencia opcional, revisión, fechas de modificación/creación y metadatos mínimos de intercambio soportados. Temporal: segundos enteros, componentes civiles y zona según [dominio](data-model.md), sin conversiones a cadenas localizadas. No almacenar texto RRULE sin validar como única fuente de verdad; usar representación de regla tipada y versionada dentro del payload.

### event_exceptions

| Columna | Tipo | Constraint |
|---|---|---|
| id | BLOB(16) | PK, NOT NULL |
| event_id | BLOB(16) | FK events.id, NOT NULL, DELETE CASCADE |
| payload_envelope | BLOB | NOT NULL, máximo 131105 bytes |

Payload: versión, clave temporal de ocurrencia original y acción `cancelled`. Reemplazos completos requieren nueva versión de payload y soporte futuro. No columna anticipada para contenido aún no soportado. La unicidad `(event_id, occurrenceKey)` se valida en dominio/repository bajo transacción: la clave está cifrada y no admite UNIQUE SQL útil sin filtrarla. Eliminar evento borra excepciones en la misma transacción.

## Índices y constraints

- PK en las cuatro tablas, UNIQUE en vault_id y esquema de singleton.
- Índice `events(calendar_id)` y `event_exceptions(event_id)` para pertenencia/cascadas.
- Sin índices en fechas, títulos, UID, hashes de texto o RRULE; tampoco índices ciegos en MVP.
- Activar foreign_keys en cada conexión y verificarlo. Validar longitudes/valores externos y límites de BLOB.
- Ninguna FK puede validar contenido cifrado: invariantes temporales, unicidad UID por calendario y excepciones se verifican tras autenticar, y nuevamente antes de commit.

Unicidad UID se aplica por calendario: un maestro por UID. Mismo UID en otro calendario puede existir, siempre con ID local distinto. La importación está aplazada; si se añade, sus duplicados deberán resolverse antes del batch. No crear ahora repositorios/batches de importación. Payloads contradictorios no se arreglan silenciosamente, también al restaurar backups.

## Consultas y coste del cifrado

Al desbloquear, leer y autenticar en lotes todos los eventos; extraer en RAM el mínimo índice: ID, calendario, variante temporal, recurrencia, título normalizado y revisión. Notas/ubicaciones permanecen descifradas solo cuando hagan falta. Este paso es O(N) y accede transitoriamente al payload completo; no afirmar que el título se descifra sin el resto del blob.

En RAM: lista ordenada por inicio para eventos únicos, lista de series, claves UID para deduplicación y mapa de excepciones. Para un rango: filtrar calendarios, intervalos que solapan y series potenciales; expandir solo la ventana con presupuesto; ordenar resultado. No descartar eventos largos solo porque su inicio precede la ventana. Búsqueda textual sobre títulos de maestros; no expansión global de recurrencias infinitas. La búsqueda de notas queda fuera del MVP.

No prometer búsquedas temporales O(log N) directamente en SQL. La propuesta prioriza no filtrar agenda en índices persistidos; medir con 10 000 eventos y hasta 100 MiB de payloads descifrados acumulados, sin retenerlos completos. Son objetivos/límites iniciales del MVP, no benchmarks logrados. Si no se cumplen, reducir tamaño admitido o revisar ADR; no añadir fechas en claro como «optimización» sin revisión.

## Conexión, archivos auxiliares y durabilidad

Propuesta: una conexión escritora, journal DELETE, synchronous FULL, foreign_keys ON, temp_store MEMORY; sin WAL inicialmente porque un solo actor evita contención. SQLite conserva journals necesarios para atomicidad: temp_store no elimina todos los auxiliares. Un cambio posterior a WAL debe abarcar backup, bloqueo y auditoría de `-wal`/`-shm`. [SQLite: temporales](https://www.sqlite.org/tempfiles.html), [WAL](https://www.sqlite.org/wal.html).

Desactivar carga de extensiones; trusted_schema OFF y defensive cuando lo permita la versión; no SQL recibido del usuario, ATTACH arbitrario, funciones que abran archivos ni interpolation de valores. Statements preparados, ownership/lifetimes C encapsulados, finalize/cierre en todos los caminos. Busy timeout acotado y cancelación sin cerrar handle mientras haya un step activo. Una segunda instancia que encuentre la bóveda ocupada no fuerza apertura ni pisa cambios. [SQLite: pragmas](https://www.sqlite.org/pragma.html).

El binding SQL contiene ciphertext, por lo que journals, páginas libres y backups SQLite no contienen nuevos textos sensibles por diseño. Sigue siendo necesario inspeccionar artefactos reales: un debug print o staging previo al cifrado rompería esa propiedad. secure_delete/VACUUM no se usan como promesa de borrado físico. Sin conversión en sitio de una hipotética DB vieja en claro: habría que crear archivo nuevo cifrado y advertir restos/snapshots.

## Versionado y migraciones

Versiones separadas: esquema físico entero monotónico; envelope criptográfico; payload de cada tipo; versión del perfil .ics independiente. user_version y schema_version deben coincidir tras commit. Nunca meter el número de esquema mutable en AAD de cada fila: la AAD usa la versión de envelope y las identidades descritas en [seguridad](security.md).

Secuencia de migración:

1. Bloquear operaciones de usuario. Validar encabezado, capacidades y espacio libre; no migrar archivo con versión más nueva.
2. Obtener clave y autenticar. Crear backup consistente de ciphertext y comprobar apertura; mantenerlo separado de la clave.
3. Ejecutar migraciones consecutivas conocidas, en transacción por salto; cambios de esquema, payloads y número de versión forman una unidad atómica. No `await` dentro.
4. Si una migración necesita descifrar, hacerlo en memoria y reencriptar antes de SQL, con nonce nuevo; aplicar invariantes y comparar conteos.
5. Comprobar integridad/FK, autenticación de registros y contratos de dominio. Commit únicamente con resultados válidos; reconstruir índice RAM.
6. Ante error/crash, rollback/recuperación del journal; conservar original/copia. Nunca reset destructivo, saltar migración o borrar evidencia automáticamente.

La migración implementada cubre únicamente la creación inicial de un archivo vacío (`user_version` 0 → 1) dentro de `BEGIN IMMEDIATE`/`COMMIT`. Un conflicto o fallo revierte el esquema; una versión futura se rechaza sin mutación. Todavía no hay migraciones de tablas con datos ni estrategia staging multiarchivo; deben añadirse antes de que exista una versión distribuida de la base.

Para transformaciones futuras demasiado grandes, diseñar migración a un archivo nuevo de ciphertext con sustitución atómica; no improvisarla al alcanzar el límite. Downgrade no soportado: conservar archivo y pedir versión compatible o restauración elegida. Retener copia previa hasta un arranque y verificación correctos; limpieza controlada de copias no elimina Time Machine.

## Corrupción y restauración hostil

Un backup también puede ser malicioso. Abrir copia de staging con límites, sin extensiones, sin confiar en triggers/views ajenos: comparar esquema con allowlist antes de mutarlo. Comprobar tamaño/versión, quick_check/integrity_check según flujo, foreign_key_check y autenticación de todas las filas. Mensajes SQL no se registran íntegros.

Una fila con tag inválido bloquea edición normal y exige recuperación; no ocultarla como evento ausente. Herramienta de salvamento parcial sería futura y explícita. Estas comprobaciones no detectan eliminación válida de filas ni sustitución por un snapshot antiguo autenticado. El perfil no promete integridad global adversarial; Q08 lo registra.
