# Privacidad de macOS, permisos y ausencia de red

La política cubre lo que genera Kansolendar. El OS, aplicaciones autorizadas y archivos que el usuario exporta tienen políticas independientes. Los defaults cambian según versión, tipo de escena y ajustes del usuario; esta tabla evita basar seguridad en defaults no controlados. Cada comportamiento debe verificarse en la matriz de macOS soportados.

## Superficies del sistema

| Mecanismo | Riesgo y comportamiento habitual/por defecto | Política propuesta / ¿deshabilitar? | Límite |
|---|---|---|---|
| Spotlight | Puede indexar tipos/rutas admitidos; Core Spotlight requiere publicación por app | No publicar eventos, no importer ni NSUserActivity indexable; bóveda en contenedor con payloads cifrados. Sí deshabilitar integración de contenido | La .app debe seguir apareciendo en Spotlight; .ics externo puede indexarse; no garantía por extensión `.noindex` |
| Quick Look | Puede mostrar archivos conocidos al pedir preview | Sin extensión de previews, sin preview de payloads o backup; no proporcionar miniaturas privadas | Un .ics exportado puede ser previsualizado por el OS/otro provider |
| Notifications | Autorización/configuración del usuario controla alertas; contenido y hora pueden persistir | Fuera del MVP, no solicitar autorización ni programar nada. Futuro: alertas genéricas opt-in | Eliminar aviso no asegura borrar toda copia/historial; una alarma revela actividad |
| Recent Documents | AppKit/DocumentGroup y apertura de documentos pueden mantener URLs | No DocumentGroup/NSDocument para bóveda; no llamar noteNewRecentDocumentURL ni menú recientes propio | Panel/Finder puede recordar carpetas/archivos fuera del control completo |
| App state restoration | Estado de escenas/ventanas puede persistir según APIs y sistema | No SceneStorage/AppStorage de contenido, búsquedas, selección o borradores; restaurar siempre locked | El OS puede retener geometría/snapshots; revisar artefactos |
| Crash reports | macOS puede generar diagnósticos y compartirlos según ajustes del usuario | Sin SDK, uploader ni anexos automáticos; errores estáticos | No apagar globalmente diagnósticos ni garantizar ausencia de fragmentos privados |
| Logs | Unified Logging conserva eventos según nivel y configuración | Solo códigos permitidos; no contenido incluso marcado private | Un perfil de diagnóstico puede cambiar redacción; [política específica](logging.md) |
| Temporary files | Frameworks y SQLite pueden generar auxiliares | Parser en memoria; staging interno solo ciphertext; limpiar huérfanos propios | Journals necesarios, swap y temporales de otros procesos |
| Clipboard | Portapapeles global; historial y Universal Clipboard pueden duplicarlo | Copia de texto solo explícita; sin copiar secretos automáticamente; no leer clipboard de fondo | No deshacer copias remotas; no borrar todo clipboard al bloquear y perjudicar otras apps |
| Screenshots / Mission Control | Pantallas y miniaturas pueden capturarse por usuario/OS | Ocultar al perder actividad/bloquear; nunca contenido en título de ventana; probar snapshots | No hay garantía pública universal de impedir captura/foto; flags de sharing no son defensa suficiente |
| Accessibility | SwiftUI expone controles para tecnologías asistivas; apps autorizadas pueden leer/interactuar | Mantener accesibilidad funcional; al bloquear retirar contenido del árbol, etiquetas neutras | No deshabilitar VoiceOver para «seguridad»; malware autorizado puede leer mientras visible |
| Backups | Time Machine y terceros pueden copiar archivos | Conservar respaldo de ciphertext y kit separado | No impedir copias, snapshots ni backup remoto de terceros |
| Autosave / Versions | Aplicaciones documentales pueden guardar revisiones | Bóveda no documental; guardar explícitamente a SQLite; sin borradores externos ni Versions | Editores/visores externos pueden autosalvar .ics exportado |
| Window state | Geometría, títulos y selección pueden terminar en saved state | Título fijo «Kansolendar»; restaurar solo geometría neutra si se verifica, nunca evento/fecha | Sistema puede retener metadatos; probar Library/Saved Application State |
| Menu items / Dock | Menús recientes, ventanas y badges pueden revelar contexto | Comandos genéricos, sin próximos eventos, nombres ni conteos; sin widget/menu bar extra | Dock/OS muestran que se usa la app |
| Undo y editores | Historial de edición conserva strings | Historial de sesión limitado; vaciar al bloquear/cerrar editor | Copias internas de framework no zeroizables con garantía |
| Corrección/dictado/servicios de escritura | Ajustes del OS pueden activar ayudas externas al producto | No integrar servicios de escritura remotos; desactivar ayudas automáticas y servicios en campos privados donde exista API pública; comprobar bridges AppKit | Usuario puede usar entrada de terceros, dictado o funciones OS; Q09, no prometer offline absoluto del sistema |
| Arrastrar, compartir, imprimir | Puede crear copias o proveedores de datos | Sin drag-out de eventos, ShareLink/servicios de compartir ni impresión en MVP | Selección/copias manuales siguen bajo control del usuario |

Restauración y recientes son integraciones que debemos evitar conscientemente: [Apple: restaurar estado SwiftUI](https://developer.apple.com/documentation/swiftui/restoring-your-app-s-state-with-swiftui), [Apple: documentos recientes](https://developer.apple.com/documentation/appkit/nsdocumentcontroller/notenewrecentdocumenturl(_:)). Notificaciones futuras requerirán autorización explícita mediante [UserNotifications](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter), sin APNs para avisos locales.

## Entitlements y permisos mínimos

| Elemento | MVP | Motivo |
|---|---|---|
| `com.apple.security.app-sandbox` | true en desarrollo/integración/release relevantes | Restringir capacidades del proceso |
| `com.apple.security.files.user-selected.read-write` | true | Paneles de exportación, backup y recuperación; sin importación de calendarios |
| Identificador de app/equipo y `keychain-access-groups` | Grupo único de app autorizado por provisioning | DP Keychain; valor de Xcode con AppIdentifierPrefix + bundle ID; auditar binario y perfil reales |
| `com.apple.security.network.client` / `.server` | Ausentes | Ninguna conexión/listener, ni localhost |
| EventKit/calendarios y `NSCalendars...UsageDescription` | Ausentes | Calendario independiente |
| Contacts, Location, Photos, Camera, Microphone | Ausentes | No los usa el MVP |
| iCloud/CloudKit/ubiquity/App Groups | Ausentes | Sin sincronización ni extensiones compartidas |
| APNs / push, background modes, login items | Ausentes | No tareas remotas ni agente de fondo |
| Apple Events / automation / scripting | Ausentes | No controlar otras apps |
| Accessibility / Screen Recording / Full Disk Access | Nunca solicitados | No necesarios; algunos son TCC, no simples entitlements |
| Downloads/Desktop/Documents de alcance amplio | Ausentes | Solo archivos elegidos |
| Persistent security-scoped bookmarks | Ausentes | Acceso temporal; no recordar carpetas |
| get-task-allow | Solo desarrollo según Xcode; ausente/false en Release | Impedir depuración ordinaria de distribución |
| Excepciones hardened runtime/JIT/library validation | Ausentes | Sin runtimes/plugins/inyección |

File access mediante panel no equivale a permiso sobre todo el disco. Abrir solo el archivo elegido, balancear start/stopAccessing cuando aplique y no persistir bookmarks. No registrar apertura de documentos .ics ni ofrecer drag-in/importación en el MVP. La restauración de backups y lectura de recuperación sí requieren acceso a archivos elegidos. Keychain presenta autenticación, no permiso de acceso al calendario. [Apple: archivos seleccionados](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.files.user-selected.read-write).

Futuro recordatorios: pedir únicamente autorización de notificaciones cuando se active la función; no añadir ahora. Geolocalización/contactos/calendario del sistema no tienen una fase planificada: exigirían nueva justificación. Mac App Store requeriría revisar firma/provisioning, no justificar permisos extras del producto.

## Offline-only: contrato implementable

No se necesita Network.framework. Tampoco URLSession, WebKit, CFNetwork usado directamente, sockets, DNS, Bonjour, listeners locales, APIs de mapas, fuentes remotas, imágenes por URL, actualizador automático, validación de licencia remota, SDK de analytics o crash reporting. No «capa de red futura». Foundation puede incluir símbolos relacionados con red en frameworks del sistema; eso no prueba que la app haga networking.

Sandbox sin entitlements client/server restringe conexiones ordinarias de la app. Ausencia de entitlement sin sandbox **no** sería suficiente. Los entitlements de red no son un firewall general contra toda comunicación vía servicios del OS, IPC, Finder o navegador delegado; por eso también se prohíben rutas de delegación, URLs abiertas desde contenido y procesos auxiliares. [Apple: entitlement de cliente](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.network.client).

Archivos elegidos pueden estar en volumen de red o proveedor cloud: rechazar archivos no locales/no descargados cuando se pueda detectar; no solicitar descargas ni coordinar materialización cloud. El sistema puede hacer actividad durante el propio panel, y la clasificación no es perfecta. La garantía del producto es que no implementa transmisión ni requiere Internet; no que controla todos los procesos del Mac. La bóveda activa siempre vive en su contenedor local.

No abrir hipervínculos automáticamente ni ofrecer URLs activas en notas. Help/Ayuda embebida. Las URL en esta documentación no se convierten en recursos de ejecución. Actualizaciones manuales como otra .app; notarización y descarga pertenecen al proceso de distribución, no al funcionamiento del calendario.

## Auditoría de red y dependencias

Revisión estática del proyecto/SPM: lista vacía de paquetes remotos, imports y llamadas de red/IPC/Process/dlopen/openURL, build scripts, resources y frameworks enlazados. Buscar dominios en código/bundle, clasificar cada resultado: identificadores de firma, UTI y documentación no son endpoints. El artefacto ejecutable no debe contener configuración de endpoints de producto ni analytics SDK. Cualquier excepción documentada debe tener propietario y motivo; no allowlist comodín.

Inspeccionar entitlements de la .app firmada, incluidas piezas embebidas; comprobar que sandbox esté activo. Ejecución en cuenta/VM de prueba con interfaz conectada y observación atribuida por proceso de DNS/TCP/UDP, y repetición sin conectividad. Cubrir startup, desbloqueo, CRUD, búsqueda, .ics con URLs, backup/restore, errores y cierre. Ningún intento atribuible, incluso fallido, es aceptable.

Un test negativo con host de prueba firmado sin entitlement debe intentar conexiones a un receptor local controlado para verificar bloqueo del sandbox; ese código vive exclusivamente en test target, nunca en producto. URLProtocol mocks no cubren sockets/CFNetwork y por sí solos no prueban ausencia de red. Separar tráfico de Gatekeeper/OS del de Kansolendar y de acciones que delegase Kansolendar. Ver [testing](testing.md).

## Ajustes y persistencia de preferencias

UserDefaults: solo tema, tamaño de texto y flags no sensibles necesarios. Zona seleccionada, calendarios visibles, fecha consultada, historial, nombres, rutas y búsquedas son datos privados: preferencias de larga duración dentro del control cifrado, o solo RAM si no son necesarias. No defaults compartidos ni sincronizados. Nunca nombres de usuario/dispositivo en UID, nombres de exportación o diagnósticos.
