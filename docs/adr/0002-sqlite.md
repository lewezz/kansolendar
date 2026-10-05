# ADR-0002: System SQLite with encrypted payloads

Documentation updated: 2026-10-05.

## Context

Local persistence must preserve transactions without a remote dependency or ORM.

## Decision reflected in the current source

Use system SQLite through the local CSQLite shim. Encrypt domain payloads before SQL. SQLiteVaultDatabase owns storage orchestration; SQLiteConnection owns the C handle and short synchronous transactions.

## History and superseded assumptions

SQLite over SwiftData/ORM was fixed by the initial stack. The schema now exists: local user_version 1 and portable user_version 2. Earlier single-location and future-schema assumptions are superseded.

## Consequences

SQL structure and relationships remain visible. There is no custom page-encryption codec, FTS index, or generic repository framework. See [database](../database.md).

## Status

Implemented in source. Current verification limits are tracked in [testing](../testing.md).
