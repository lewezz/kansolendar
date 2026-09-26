# ADR-0001 — SwiftUI para aplicación macOS nativa

## Context

El producto debe ser una .app convencional y autónoma. El stack exige Swift 6 y SwiftUI, sin runtime externo ni web empaquetada. La UI debe poder ocultar todo el contenido privado al bloquear.

## Decision

Usar SwiftUI para escenas, vistas y navegación; ViewModels en MainActor. Adaptadores AppKit pequeños para paneles/ciclo de ventanas o controles de privacidad que SwiftUI no exponga suficientemente. No sustituir la UI por AppKit completo ni importar frameworks de navegador.

## Alternatives

AppKit completo da más control pero contradice la elección de UI y eleva coste inicial. Electron/WebView/runtime externo incumplen requisitos. Un wrapper web no cumple la superficie nativa deseada.

## Consequences

Accesibilidad y comportamiento macOS deben probarse, no darse por resueltos por el framework. No usar DocumentGroup/SceneStorage para datos privados. El mínimo macOS y APIs concretas se decidirán antes del skeleton. UI declarativa puede retener valores: limpiar todos los estados al bloquear.

## Status

SwiftUI/Swift 6 fijados por requisitos. Uso de adaptadores y mínimo macOS propuestos; Q06/Q07 pendientes. Ver [arquitectura](../architecture.md).
