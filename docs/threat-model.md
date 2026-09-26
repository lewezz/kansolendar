# Modelo de amenazas

Estado: análisis previo a la arquitectura; revisar ante cambios de alcance. Orden de prioridad: privacidad/seguridad, corrección, fiabilidad, mantenibilidad, simplicidad, rendimiento, funcionalidades.

Revisión de alcance, 2026-09-25: importación de calendarios aplazada por el propietario. T26 y los flujos de entrada .ics se conservan como análisis futuro; no existe esa entrada en el MVP. Los backups, kits y payloads siguen siendo entrada no confiable. Apple silicon exclusivo reduce la matriz de hardware; no elimina amenazas de acceso al usuario ni privilegios.

## Activos, adversarios y confianza

Activos: títulos, notas, lugares, horarios, zonas, nombres de calendarios, patrones de recurrencia, UID importados, búsquedas, clave de bóveda, recuperación, copias y estado de edición. La existencia de una agenda y el volumen de actividad también son información.

Se distinguen: observador casual; ladrón con Mac apagado; persona con sesión abierta o credenciales; proceso del mismo usuario; malware con Accessibility/Screen Recording/Full Disk Access; administrador/root o kernel comprometido. No se supone que todos puedan extraer Keychain automáticamente, ni que compartir usuario sea una frontera fuerte.

```text
archivo .ics / backup no confiable
              |
        límite de validación
              v
 proceso Kansolendar (UI + dominio + adaptadores)
   memoria sensible SOLO durante sesión desbloqueada
       |                          |
       v                          v
 SQLite: payloads cifrados     Keychain: clave local
       |                          |
       +----- macOS / usuario / hardware -----+
                     |
        copias, snapshots, captura, diagnósticos

salidas deliberadas: .ics legible / backup / clave de recuperación
```

El sandbox restringe la aplicación comprometida; no es una caja hermética que vuelva inaccesible su memoria o archivos a todo el sistema. No hay servidores de confianza ni canales de sincronización.

## Clasificación

Probabilidad **B/M/A** = baja/media/alta de forma cualitativa para un Mac personal usado varios años, no estadística ni porcentaje medido. «Cond.» significa que aumenta mucho al cumplirse la precondición. Impacto **A/C** = alto/crítico; «M» = moderado. Robo y malware dependen del entorno. Se priorizan también amenazas poco probables con impacto catastrófico.

| ID / amenaza | Impacto | Prob. y condición | Mitigación propuesta / decisión | Residuo y fuera de alcance |
|---|---|---|---|---|
| T01 Acceso físico a pantalla abierta | A: lectura/copia | M; A con sesión visible | Bloqueo manual, al perder actividad y al suspender; ventanas neutras. ADR-0007 | Fotografías previas, observador presente y reacción antes del bloqueo |
| T02 Robo de Mac apagado | C: archivo y claves | M | Recomendar FileVault, Keychain local y payloads cifrados. ADR-0004/0005 | Hardware/OS vulnerado, contraseña del usuario o recuperación robada |
| T03 Acceso a cuenta macOS | C | M; A con credenciales conocidas | Presencia de usuario para Keychain; no contraseña propia en MVP | Contraseña del Mac puede satisfacer autenticación; no segundo factor independiente |
| T04 Copia de .app/configuración | M: ingeniería/revelación | A | Ningún secreto embebido, preferencias sin PII, firma. ADR-0012 | Diseño y código recuperables; no depender de ofuscación |
| T05 Copia de SQLite, WAL, journal | C para contenido; M metadatos | M | Cifrar antes de bind; horarios y UID dentro del payload. ADR-0004 | Número/tamaño/relaciones de registros visibles; DB + clave revela contenido |
| T06 Acceso a backups | C | M | Payloads cifrados también en copias; clave fuera del backup; verificar restauración | Copias antiguas, clave guardada junto a ellas, backup OS con credenciales |
| T07 Temporales y staging | A | M | Solo ciphertext en staging interno; parser en memoria y con límites | .ics elegido por usuario es legible; swap y archivos de otras apps |
| T08 Logs | A | M | Códigos cerrados; cero interpolación de datos/errores arbitrarios | OS/depurador puede generar datos fuera del logger propio |
| T09 Crash reports | A | B/M | Sin SDK ni envío propio; excepciones genéricas; no adjuntar DB | Diagnósticos del sistema y soporte manual no controlables totalmente |
| T10 Memory dumps | C | B; A con privilegios/debug | Release endurecida, no get-task-allow, vida corta de claves/plaintext | Memoria necesariamente legible al usar datos; root/kernel fuera de defensa |
| T11 Swap/hibernación | A | M condicionado | Reducir cachés/copias, recomendar FileVault, borrar referencias al bloquear | Swift no garantiza zeroización; política de paginación del OS fuera del control |
| T12 Preferencias/estado restaurado | A | M | Solo ajustes no sensibles; sin borradores, fecha seleccionada ni historial | El sistema puede mantener metadatos de ventanas |
| T13 Notificaciones | A | A si contienen títulos | Fuera del MVP; futura opción genérica y explícita. ADR-0011 | El centro de notificaciones retiene información y momentos de actividad |
| T14 Spotlight | A | M si se publica/indexa | Sin Core Spotlight, NSUserActivity indexable ni importer propio | Archivos .ics exportados pueden indexarse; nombre .app sí debe encontrarse |
| T15 Quick Look | A | M en exportación | Sin preview provider ni vista previa de la bóveda | El OS puede previsualizar un .ics externo; no revocable por Kansolendar |
| T16 Permisos excesivos | C | M | Allowlist mínima; no EventKit, contactos, red, automatización ni Full Disk Access | Permisos dados a terceros no los controla la app |
| T17 Procesos externos mismo usuario | A/C | M | Permisos de archivos restrictivos y Keychain por identidad; sandbox | ACL POSIX del usuario no separa todos sus procesos; IPC/OS confiables |
| T18 Malware del usuario | C | B/M; A si infectado | Minimizar APIs y salidas; autenticación y bloqueo | Puede capturar entradas o aprovechar sesión desbloqueada; sin promesa antimalware |
| T19 Malware con permisos adicionales | C | B; A si autorizado | No solicitar esos permisos; firma y hardened runtime | Accessibility, Screen Recording, root/kernel pueden superar barreras |
| T20 Acceso a Keychain | C | B/M | Data Protection Keychain, no sincronizable, userPresence, identidad estable | Credenciales, autorización engañosa y fallos del OS; pruebas reales obligatorias |
| T21 Ingeniería inversa/modificación del binario | A | M | Cripto estándar, no secretos en código; firma y notarización | Copias modificadas fuera de cadena de confianza, no DRM |
| T22 Inferencia/extracción de DB | A | M tras copia | Sin índices temporales/FTS en disco; AAD liga registros | Conteos, pertenencia a calendario, tamaños y comparación de snapshots visibles |
| T23 Recuperación de borrados | A | M con snapshots | Nunca persistir plaintext; política de retención de copias | No borrado físico garantizado en SSD/APFS/Time Machine; clave vigente abre ciphertext antiguo |
| T24 Errores de implementación | C | M | Contratos, pruebas de fallos, transacciones y revisión de seguridad | Bugs desconocidos; compilación no prueba seguridad |
| T25 Debugging accidental | C | M en desarrollo | Fixtures sintéticas, llavero/ID separados; sin trazas SQL/dumps | Un desarrollador autorizado puede inspeccionar su proceso |
| T26 .ics hostil | A/C: bloqueo/pérdida | M | Límites bytes/expansión, parser estricto, sin URLs activas. ADR-0010 | Compatibilidad incompleta; fallos del framework/OS |
| T27 Manipulación/replay de DB | A: datos falsos/ausentes | B/M con escritura | AEAD + AAD, FK e invariantes; fallar ante corrupción | AEAD por fila no detecta toda eliminación ni rollback válido; no historial antirrollback |
| T28 Pérdida de clave/corrupción | C: pérdida definitiva | M | Recuperación separada y restauración probada; nunca recrear encima | Sin clave ni recuperación no se descifra; sin backup no se reconstruyen datos |
| T29 Clipboard, capturas, Accessibility | A | M | Copia solo explícita, no copiar secretos automáticamente; ocultar al bloquear | Historial de portapapeles, fotos, herramientas autorizadas y VoiceOver mientras visible |
| T30 Exportación a ubicación sincronizada | C | M | Explicar salida legible, selector explícito; backup no incluye clave | El usuario/OS puede sincronizar archivos; no se garantiza permanencia física tras exportar |

## Objetivos verificables y no objetivos

Objetivos: ninguna persistencia interna de contenido legible; ausencia de código de networking; acceso a datos solo después de desbloquear; importación sin ejecución ni dereferenciación externa; corrupción nunca interpretada como base vacía; ausencia de datos privados en logs propios.

No objetivos: confidencialidad ante OS malicioso, secreto ante el dueño con credenciales y recuperación, protección de datos ya exportados, prevención absoluta de screenshots, borrado forense, disponibilidad ante destrucción física, detección completa de replay o garantía de que macOS no se conecte a sus servicios.

## Riesgos que requieren aceptación

1. Cifrado de payloads deja metadatos, y obliga a búsquedas/índices en RAM: Q01/Q02.
2. Recuperación portable entrega un secreto equivalente a la clave: Q04.
3. Autenticación macOS no proporciona contraseña independiente: Q03.
4. El perfil .ics inicial no acepta todos los calendarios reales: Q05.

La [matriz de pruebas](testing.md) vincula los grupos de amenazas con evidencia. Las defensas de FileVault y sandbox son capas diferentes: [Apple: FileVault](https://support.apple.com/en-au/guide/security/sec4c6dc1b6e/web), [Apple: App Sandbox](https://developer.apple.com/documentation/security/app-sandbox).
