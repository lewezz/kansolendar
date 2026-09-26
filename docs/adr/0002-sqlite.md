# ADR-0002 — SQLite explícito, sin SwiftData ni ORM

## Context

El producto necesita persistencia local fiable, control de archivos auxiliares y migraciones, y una frontera clara para cifrar antes de escribir. SQLite es requisito; SwiftData y ORM se excluyen inicialmente.

## Decision

SQLite del SDK mediante API C encapsulada en Storage. Esquema pequeño y repositorios de negocio; statements preparados, conexión única aislada y migraciones explícitas. No añadir otra distribución de SQLite, extensión ni paquete remoto.

## Alternatives

SwiftData/Core Data simplifican modelado pero no cumplen la elección ni garantizan el cifrado requerido. ORM facilita SQL a costa de superficie y dependencia. Archivos JSON planos complican transacciones/integridad y no son la persistencia elegida.

## Consequences

Hay que gestionar correctamente ownership de buffers, errores, FK, transacciones y versiones. SQLite de cada macOS puede diferir: capacidades se verifican. Cifrar payloads impide índices SQL sobre contenido; se acepta coste en RAM sujeto a Q02. El esquema no expone fechas por conveniencia.

## Status

Tecnología fijada por requisitos. Diseño físico propuesto, dependiente de ADR-0004. Referencia: [database.md](../database.md).
