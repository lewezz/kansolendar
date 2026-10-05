# ADR-0012: Single macOS app and pending GitHub delivery

Documentation updated: 2026-10-05.

## Context

The deliverable should be one conventional macOS app that users can obtain through the requested GitHub channel.

## Decision reflected in the current source

Maintain the sole Kansolendar target/scheme and arm64/macOS 14 configuration. Establish concrete packaging and release identity separately; the previous project configuration used Apple Development signing and a development bundle identifier.

## History and superseded assumptions

The original proposal described a signed/notarized direct-distribution process. It is historical and was not implemented as a release pipeline. Apple Silicon-only scope was decided on 2026-09-25 and macOS 14 minimum on 2026-09-26. The current user-requested channel is GitHub; packaging and installed-app launch validation remain open.

## Consequences

A development build or the name Release is not a verified distribution artifact. No alternate application variant, updater, publication pipeline, or permanent launch guarantee is present. See [distribution](../distribution.md).

## Status

App configuration implemented; delivery decision and artifact verification pending. Current verification limits are tracked in [testing](../testing.md).

## Current implementation update

The password-only whole-document format and ad hoc signing supersede the relevant
legacy assumptions above. See [ADR-0014](0014-whole-document-vaults.md),
[current persistence](../database.md), and [distribution](../distribution.md).
