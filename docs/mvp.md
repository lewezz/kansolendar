# MVP propuesto

Un calendario pequeño que pueda usarse y restaurarse sin red. La seguridad no es una fase opcional posterior. El propietario ha aceptado cifrado de contenido, autenticación macOS y recuperación separada; también ha aplazado la importación de calendarios y descartado Intel (2026-09-25). El resto del diseño sigue sujeto a revisión y validación técnica.

## Incluido

- `.app` macOS nativa para Apple silicon (arm64), una ventana principal, UI SwiftUI con teclado y accesibilidad.
- Bóveda local única, varios calendarios simples con nombre/color y uno inicial.
- Vista mensual y lista del intervalo seleccionado; navegación y «hoy». Sin editor gráfico semanal complejo.
- Crear, editar y eliminar eventos con título, notas de texto plano, ubicación textual y calendario.
- Eventos UTC/zona explícita y all-day; rangos que cruzan medianoche, DST validado y gregoriano definido.
- Recurrencias del perfil reducido: diaria/semanal/mensual/anual, intervalo, final opcional; cancelar una instancia y modificar contenido de serie. Restricciones temporales con excepciones según dominio.
- Búsqueda de títulos en memoria y filtros por calendario/intervalo.
- Payloads sensibles cifrados desde la primera escritura; Keychain local, autenticación de sistema y bloqueo.
- Backup consistente cifrado a nivel de contenido, kit de recuperación separado y restauración comprobada.
- Exportación `.ics` del perfil limitado y conversiones explícitas; errores sin pérdida silenciosa. Sin importación de calendarios en el MVP.
- Logging sin contenido, sandbox mínimo, ausencia de red/analytics, tests y auditoría de distribución.

Límites iniciales propuestos: 10 000 maestros, 100 MiB de payloads acumulados, rango expandido hasta 366 días y presupuesto de ocurrencias/candidatos de [dominio](data-model.md). El límite de entrada .ics queda reservado al diseño futuro de importación. Son límites verificables, no garantías de rendimiento aún medidas.

## Fuera del MVP

Importación de calendarios (incluidos parser, preview y apertura de archivos .ics); soporte Intel/Universal 2; recordatorios/notificaciones; asistentes e invitaciones; adjuntos; tags; ubicaciones geográficas/mapas; floating; VTIMEZONE custom; compatibilidad total RFC; RDATE/BYSETPOS y reglas avanzadas; edición de instancia desplazada o «esta y siguientes»; soporte no gregoriano; integración con calendarios del sistema; widgets/menu bar; impresión; drag-out/compartir; multiwindow; contraseña propia; rotación de clave asistida; antirrollback; índices SQL sobre contenido en claro; múltiples bóvedas; Mac App Store.

Restaurar un backup de Kansolendar sigue incluido: es recuperación de la bóveda, no importación de calendarios externos.

**Fuera del producto definido**, sin módulos ni roadmap reservado: sincronización, cuentas, backend/servidores, colaboración, funciones sociales, integración Google Calendar/Outlook/iCloud, analytics, telemetría, updater remoto y servicios de IA. Mencionar archivos exportados por otras apps en fixtures no constituye integración.

## Qué debe poder hacer el primer usuario

Instalar la .app, crear y desbloquear bóveda, guardar una cita y una serie simple, cerrar y reabrir sin conexión, buscar/ver los datos correctos, bloquear sin dejar contenido visible, exportar voluntariamente un .ics entendiendo sus límites, crear backup/recuperación y restaurar en una cuenta sin el Keychain original.

No se considera MVP terminado si solo funciona CRUD pero no restauración, o si la DB cifrada produce copias legibles accidentales. Tampoco si exporta una serie cambiando sus horarios sin explicarlo. Si el esfuerzo obliga a reducir alcance, recortar vistas o recurrencias antes de cifrado, recuperación, validación y pruebas.
