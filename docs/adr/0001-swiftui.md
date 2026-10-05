# ADR-0001: Native SwiftUI application

Documentation updated: 2026-10-05.

## Context

The product needs a conventional macOS application without a web runtime or external interpreter.

## Decision reflected in the current source

Use Swift 6 and SwiftUI for the macOS app, with focused AppKit adapters for native file panels and system actions. Configuration targets macOS 14 and arm64.

## History and superseded assumptions

The native stack and Apple Silicon-only scope were established in the original requirements. The current project implements one app target; the original future-project wording is obsolete.

## Consequences

Views, forms, and appearance stay in the app layer. Core and Storage remain UI-independent. Latest app compilation and OS behavior still need verification.

## Status

Implemented in source. Current verification limits are tracked in [testing](../testing.md).
