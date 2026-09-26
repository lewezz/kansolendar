# ADR-0010 — .ics manual con perfil limitado y validado

## Context

iCalendar es el formato requerido; su semántica temporal y extensiones exceden un MVP sin dependencias. Un parser que «aproxima» zonas/reglas puede alterar la agenda sin que se note.

## Decision

MVP con exportador local acotado; **importación aplazada por decisión del propietario**. No parser, preview de entrada, comando de importación ni asociación para abrir .ics. Mantener el análisis de entrada hostil como referencia futura. No invitaciones ni URLs activas. Exportación zoned única a UTC y series zoned materializadas solo mediante elección explícita con advertencia; backup conserva fidelidad completa.

## Alternatives

RFC completo aumenta mucho scope. Librería externa viola dependencia inicial. EventKit requiere integración del sistema no deseada y no es un codec puro para este producto. Ignorar propiedades temporales desconocidas se rechaza por corrección.

## Consequences

Ningún calendario externo se importa en el MVP; se reduce superficie y esfuerzo de parser. Sin compatibilidad universal prometida. Contenido exportado es legible; el sistema puede indexarlo/sincronizarlo. Límites y pérdidas de exportación se hacen visibles antes de escribir. Restauración de backup permanece incluida. Añadir importación exige revisar perfil y pruebas en otra fase, sin asumir fecha comprometida.

## Status

Formato fijado. El diseño inicial incluía importación; **el propietario la aplaza el 2026-09-25** («no hace falta importar calendarios de momento»). Q05 queda resuelta para el alcance inicial; los detalles de exportación siguen propuestos. Referencia contractual: [icalendar.md](../icalendar.md).
