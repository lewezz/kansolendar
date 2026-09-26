# Errores y logging privado

Regla de diseño: un logger no recibe contenido privado. Marcar un dato como `.private` no autoriza a registrarlo; configuraciones del sistema pueden alterar redacción. La protección de OSLog es una defensa adicional, no el filtro de datos del producto. [Apple: OSLogPrivacy](https://developer.apple.com/documentation/os/oslogprivacy).

Importación .ics aplazada: las categorías e informes de importación descritos aquí son restricciones futuras, no motivo para crear un logger, parser o flujo de entrada ahora.

## Allowlist y prohibiciones

| Permitido | Ejemplo conceptual |
|---|---|
| Código de error de catálogo cerrado | STORE_FULL, AUTH_CANCELLED, FORMAT_UNSUPPORTED |
| Versión de app/esquema y subsistema estático | storage, import, security |
| Resultado de operación sin identificadores | failed / cancelled; solo cuando justifique diagnóstico |
| Métricas agregadas de rendimiento en fixture de desarrollo | Duración de benchmark sintético, nunca sesiones reales |

Prohibido siempre, también en Debug con datos reales: títulos, notas, ubicación, asistentes, calendarios, fechas/horas de eventos, zona personal, UID, IDs de bóveda/fila, ruta de archivo, nombre de usuario/equipo, búsquedas, SQL con bindings, plaintext, ciphertext, nonce/tag volcados, clave, recuperación, contenido .ics, clipboard y capturas. Ciphertext/IDs pueden correlacionar copias aunque no sean texto legible. No registrar conteos ni cronología de uso en producción para fabricar analytics locales.

No `print`, `dump`, `String(describing: event)`, errores interpolados, NSError.userInfo completo, sqlite3_trace, texto de `sqlite3_errmsg`, assert con input ni mensajes de crash con contenido. Traducir errores externos a códigos conocidos en el borde. Parámetro dinámico inesperado se omite, no se «sanitiza» con expresiones regulares insuficientes.

## Niveles y entornos

- Debug: solo diagnóstico de flujo con constantes y fixtures sintéticas; logger compilado/controlado para no poder activar dumps privados. No flag secreto de «verbose sensible».
- Info: desactivado por defecto en producción salvo hitos técnicos excepcionalmente justificados; sin startup/event tracking rutinario.
- Warning: incompatibilidad recuperable o recurso limitado, código estático; repetición limitada.
- Error: operación fallida que requiere atención; código de catálogo y subsistema.
- Fault: invariante interna rota, sin datos de la entidad. Fallar de forma controlada cuando sea posible.

Sin archivos de logs propios persistentes ni rotación casera, sin SDK, sin upload. Unified Logging queda sujeto a retención del OS. Un bundle de soporte futuro debe ser explícito y revisable, sin DB/llavero ni carpetas enteras; no entra en MVP. Desarrollo usa bundle ID, contenedor y Keychain de fixtures separados; jamás abrir la bóveda real en debugger para testear.

## Modelo de errores

| Familia | Acción de UI | Recuperación |
|---|---|---|
| Validación | Señalar campo mientras desbloqueado, sin logger de su valor | Corregir; no escribir |
| .ics incompatible | Informe local de componente por ordinal/código | Excluir componente o cancelar |
| Cancelación de usuario | Cerrar flujo sin banner alarmista | Estado previo intacto |
| Bloqueada/generación obsoleta | Volver a pantalla neutra | Desbloquear de nuevo; no replay automático de escritura |
| Keychain ausente/denegado | Explicación limitada y opción de recuperación | No generar nueva clave sobre DB existente |
| Conflicto de revisión | Indicar edición obsoleta | Recargar explícitamente; no sobrescribir |
| Disco lleno/permiso/busy | Mantener borrador en sesión y mostrar error | Reintento limitado solo si es idempotente |
| Corrupción/AEAD inválido | Impedir edición normal y proponer restauración | Preservar archivo; no reset automático |
| Versión más nueva | Explicar incompatibilidad | App compatible/restauración; no downgrade |
| Error interno | Mensaje genérico y código | Mantener estado confirmado, no filtrar descripción de objetos |

No reintentar autenticación en bucle. Un guardado cuyo commit es incierto se resuelve releyendo revisión/ID interno bajo sesión válida antes de duplicar acción. Los informes de importación detallados son UI de sesión, no logs; se eliminan al bloquear. Exportar informe futuro requeriría advertencia y revisión separadas.

Verificación: canarios privados en cada campo, forzar errores, revisar stdout/stderr, Unified Logging y crash artifacts; prueba adicional que inspecciona llamadas al logger para impedir tipos privados. Un test de texto no demuestra ausencia de toda fuga, por lo que se combina con revisión de API y binario Release. Ver [testing](testing.md).
