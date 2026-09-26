# Modelo conceptual de dominio

Este documento define el contrato conceptual; los tipos Swift de `KansolendarCore` lo implementan sin acoplarse a persistencia. Las entidades son valores del dominio, independientes de cómo se codifiquen dentro de los payloads cifrados. El vocabulario evita confundir `Calendar` de negocio con `Foundation.Calendar`: el tipo es `LocalCalendar`.

## Contrato implementado en Core

`CivilDate` valida el calendario gregoriano proléptico mediante aritmética civil, sin normalizar fechas inválidas. `Instant` conserva segundos Unix con signo. `LocalDateTime` no incorpora zona; `TimeZoneID` valida el identificador y `FoundationLocalTimeResolver` resuelve con coincidencia estricta, rechaza huecos DST y exige elegir primera/última ocurrencia en pliegues.

`EventTime` contiene `AllDayEventTime`, `TimedEventTime` UTC o `ZonedEventTime`. Las duraciones temporales deben ser positivas y su fin debe ser representable. Los calendarios y eventos tienen UUID independientes; UID se genera a partir del UUID local si no se proporciona para exportación. Se aplican los límites de bytes documentados en este archivo.

`RecurringSeries` mantiene la regla fuera del registro `Event`; la recurrencia es una definición y `EventOccurrence` una proyección calculada. El motor acepta únicamente consultas del mismo tipo temporal que la serie, rango de hasta 366 días, máximo predeterminado de 100 000 candidatos y 20 000 resultados. Agotar cualquier límite produce error y descarta el resultado parcial. COUNT cuenta comienzos válidos antes de las cancelaciones; horas inexistentes y fechas mensuales/anuales inválidas se omiten. La expansión de series históricas empieza en DTSTART y puede alcanzar el presupuesto antes de una consulta muy lejana.

`EventSearch` filtra registros en memoria por calendario, título normalizado e intervalo. No expande recurrencias: el llamador combina búsqueda de definiciones y `RecurrenceEngine` de forma explícita. La normalización de título usa Foundation/ICU del sistema y puede cambiar entre versiones de macOS.

La importación de calendarios está aplazada (decisión del propietario, 2026-09-25). Las reglas sobre UID importado, SUMMARY ausente o conversiones de entrada son referencia futura, no servicios del MVP. UID de eventos creados sigue siendo necesario para exportación; backups conservan fielmente el modelo local.

## Entidades, valores y relaciones

| Concepto | Identidad y contenido | Invariantes / alcance |
|---|---|---|
| Vault | UUID aleatorio; calendarios y preferencias privadas | Una por instalación/usuario en MVP; no cuenta ni contraseña propia |
| Calendar | UUID local; nombre, color de paleta, orden, zona predeterminada | Nombre no vacío; renombrar no cambia ID; zona sirve de valor inicial, no modifica eventos existentes |
| Event | UUID local; calendarID, UID de intercambio, título, notas, ubicación, tiempo, revisión | Pertenece a un calendario; título no vacío para creación UI; importado sin SUMMARY se representa sin inventar contenido |
| RecurringSeries | Event maestro + RecurrenceRule + cancelaciones | Regla vive en una definición separada del registro Event; cancelaciones usan claves de inicio original |
| Occurrence | Clave lógica `(eventID, inicio original)`; intervalo calculado | Proyección de una serie, no fila por ocurrencia; identidad no depende del mes mostrado |
| RecurrenceRule | Valor de regla admitida | Una regla por maestro, sin expansión infinita persistida |
| EventException | UUID interno; eventID, clave original, cancelación o reemplazo | Como máximo una por clave original; reemplazo completo futuro, cancelación en MVP |
| Reminder | Futuro: ID, evento, desplazamiento respecto al inicio, modo genérico | No existe en MVP, ni se programa ni se pide permiso. Requerirá semántica DST, cambios, app cerrada y bloqueo |
| Attendee/Organizer | Futuro: dirección y nombre como datos pasivos | Fuera del MVP; jamás envío de invitaciones, contactos ni RSVP automático |
| Location | Texto opcional acotado | Sin geocodificación, MapKit, coordenadas ni hipervínculo automático |
| TimeZoneID | Identificador reconocido de zona, p. ej. Europe/Madrid | No abreviaturas ambiguas como CST; no inferir zona a partir de offset |
| CivilDate | Año, mes, día gregorianos | Fecha real, sin zona ni hora, no `Date` a medianoche |
| LocalDateTime | CivilDate + hora/minuto/segundo | Puede ser inexistente/ambiguo en una zona; resolver explícitamente |
| Instant | Segundos enteros con signo desde Unix epoch | Punto temporal independiente de zona; precisión MVP de segundos |
| Tags / Attachments | No se modelan en MVP | Un calendario ya clasifica; adjuntos añaden parsers, almacenamiento y salidas innecesarias |

Identificadores locales: UUID aleatorios, nunca email, nombre de equipo ni timestamp. UID de iCalendar es otra identidad: texto opaco, sensible y cifrado; no usarlo como PK ni ruta. Eventos creados generan un UUID serializado como UID sin dominio externo. UID importado se conserva en el perfil sin pérdida; no se normaliza a minúsculas.

Eliminar calendario exige confirmar eliminación de sus eventos o moverlos a otro calendario en una operación explícita. No cascadas silenciosas por interacción UI. Crear un calendario inicial local; permitir varios calendarios simples en MVP. Un nombre duplicado puede permitirse: identidad es UUID. No calendario del sistema.

## Representación temporal

Tres variantes excluyentes:

1. **All-day**: inicio CivilDate y fin CivilDate exclusivo, ambos obligatorios. Una jornada es `[2026-09-25, 2026-09-26)`. Su duración se cuenta en días civiles, no en múltiplos de 86 400 segundos.
2. **UTC timed**: inicio Instant y duración exacta positiva en segundos. Fin = inicio + duración con detección de overflow. No cambia al viajar.
3. **Zoned timed**: inicio civil original, TimeZoneID, instante resuelto y elección de pliegue (`first`/`last`) para esa resolución, con duración exacta positiva. La zona y hora civil gobiernan una recurrencia; el instante guardado fija el evento único/primera ocurrencia. No almacenar únicamente UTC si existe intención de repetir a una hora local.

No eventos floating en MVP: importarlos exige elegir explícitamente una zona y aceptar una conversión, o rechazarlos. Ese flujo de conversión queda fuera del primer perfil .ics para mantenerlo pequeño. La zona de visualización es una preferencia diferente; cambiarla no reescribe los datos. No usar `Calendar.current`/`TimeZone.current` dentro de reglas sin pasarlos explícitamente.

Convención de intervalos: `[start, end)`. Se solapan si inicioA < finB y finA > inicioB. Fin exacto al comienzo del día siguiente no ocupa ese día. Los eventos cruzando medianoche conservan una identidad; las vistas pueden dividir su dibujo. All-day y timed se comparan mediante rangos separados; para visualización conjunta se usa la zona seleccionada.

Se proponen fechas civiles entre 0001-01-01 y 9999-12-31, calendario **gregoriano proléptico**, sin año cero, BCE ni segundos intercalares. El fin exclusivo también debe ser representable: no ofrecer un all-day que termine en año 10000. Validación estricta: nunca normalizar 30 de febrero a marzo. Los instantes derivados fuera del rango admitido se rechazan. Los datos previos a 1970 usan segundos negativos. El rango es un contrato de producto a validar en Foundation; no depende de su capacidad de normalización.

La exactitud de offsets históricos y leyes futuras depende de los datos de zona incluidos en macOS. No equivale a reconstruir calendarios civiles históricos de cada país. Capturar la versión de reglas de zona cuando sea accesible para detectar cambios; los instantes de eventos únicos permanecen fijos, las series futuras se recalculan con la zona del sistema. Si cambia la resolución del inicio maestro frente a su instante guardado, marcar conflicto temporal y exigir revisión antes de alterar la serie; no modificarla silenciosamente. Versiones antiguas de tzdata no se descargan ni se empaquetan inicialmente.

## DST y ambigüedades

En creación UI: una hora inexistente se rechaza con explicación; una hora repetida permite elegir primera o segunda ocurrencia mostrando el offset. Un evento recurrente del MVP utiliza la **primera** ocurrencia de horas repetidas; una selección de segunda ocurrencia impide convertirlo en serie sin revisión explícita. Esto evita guardar una regla cuya primera instancia discrepe del resto.

Ejemplos de prueba: Europe/Madrid 2026-03-29 02:30 no existe; 2026-10-25 02:30 ocurre dos veces. Una reunión semanal a las 09:00 mantiene 09:00 local aunque cambie UTC. El día de transición puede durar 23 o 25 horas; un all-day sigue siendo una fecha.

Foundation ofrece políticas de búsqueda y repetición, pero no sustituye la validación de dominio. Verificar ida y vuelta de componentes y elegir políticas explícitas; no confiar en defaults que ajustan horas. [Apple: Calendar.MatchingPolicy](https://developer.apple.com/documentation/foundation/calendar/matchingpolicy).

## Recurrencias: contrato del MVP

Perfil propio reducido: `DAILY`, `WEEKLY`, `MONTHLY`, `YEARLY`; `INTERVAL` entre 1 y 999; final abierto, `COUNT` entre 1 y 100 000 o `UNTIL`, nunca ambos. Weekly admite lista de días sin ordinal y `WKST=MO`; DTSTART debe pertenecer a los días elegidos. Monthly repite el día de DTSTART; yearly su mes/día. Sin BYSETPOS, BYWEEKNO, ordinales, listas BYMONTHDAY, RDATE ni otras combinaciones en MVP.

La expansión trabaja con componentes civiles para zoned/all-day y componentes UTC para UTC timed. Nunca sumar 86 400 segundos para avanzar un día zoned. Se generan candidatos válidos, se aplica final y después cancelaciones. El inicio original forma la clave de ocurrencia aunque posteriormente se mueva una instancia. COUNT cuenta inicios válidos antes de exclusiones; DTSTART cuenta como primero. UNTIL es inclusivo para el inicio: CivilDate para all-day e Instant UTC para timed, también si la serie es zoned. El editor resuelve explícitamente el límite elegido en la zona de la serie y lo guarda sin depender luego de la zona de visualización. Fechas/horas de inicio imposibles se omiten; 31 mensual no se convierte en último día, 29 de febrero anual no se convierte en 28.

La duración de timed es exacta, no «misma hora de final local»: una hora dura 3 600 segundos también en transición DST. All-day mantiene duración en días civiles. Se explica esta elección en el editor; no soportar dos semánticas de duración indistinguibles.

Consulta siempre acotada: rango de vista hasta 366 días, presupuesto de 20 000 ocurrencias y 100 000 candidatos por operación. Son límites iniciales de producto, pendientes de medición. Si se alcanzan, devolver error específico o pedir rango menor, nunca truncar como si el resultado estuviera completo. Considerar inicios anteriores al rango cuyo fin lo atraviesa. COUNT desde un pasado lejano exige contar correctamente los candidatos omitidos; no usar un salto aritmético que cambie la secuencia. Si el presupuesto impide calcularla, informar.

Cancelación de una instancia: registro con su inicio **original**; exportación compatible como EXDATE. MVP permite editar contenido de toda la serie y cancelar una instancia. Cambiar regla/inicio/zona/duración cuando hay excepciones queda bloqueado hasta que el usuario elija crear otra serie o quitar explícitamente esas excepciones; no reasignarlas por heurística. «Esta y siguientes», mover una instancia y editar excepciones completas quedan fuera del MVP aunque el modelo conceptual reserve su significado.

El perfil sigue conceptos de iCalendar y se limita deliberadamente; las reglas normativas sobre DTSTART/UNTIL/EXDATE y fechas inválidas se contrastarán con [RFC 5545, secciones 3.3.10 y 3.8.5](https://www.rfc-editor.org/rfc/rfc5545). No se declara soporte completo del RFC.

## Límites de contenido y reglas de integridad

Propuesta inicial: nombre de calendario 256 bytes UTF-8; título 1 024; ubicación 4 KiB; notas 64 KiB; UID 1 024; payload descifrado máximo 128 KiB. Límites de bytes además de caracteres para controlar recursos. Mantener Unicode original, rechazar NUL/controles peligrosos donde no procedan; no convertir notas a HTML. Saltos de línea admitidos en notas, no en nombres de archivo derivados porque **no se derivan nombres de archivo del contenido**.

No fin anterior/igual a inicio en timed del perfil MVP. Los eventos iCalendar instantáneos válidos pero sin duración se rechazan como incompatibilidad de perfil, no como archivo malicioso. No restricciones arbitrarias sobre solapamientos entre eventos: son válidos. Cada escritura aumenta revisión; timestamps de creación/modificación son metadatos privados cifrados, no prueba confiable de orden frente a cambios del reloj.

Reloj, zona de visualización y resolución de zonas se inyectan para pruebas. Formatos localizados solo en presentación. Búsqueda por título y filtros de calendario/intervalo en MVP; normalización de búsqueda en memoria, sin cambiar originales.
