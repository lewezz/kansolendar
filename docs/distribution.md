# Build y distribución futura

No se crea proyecto Xcode, firma, certificado ni artefacto en esta fase. Objetivo: `Kansolendar.app` autónoma que se copia a `/Applications` y se abre desde Finder, Dock o Spotlight, sin instalador de runtime ni servidor.

## Build

Xcode como dueño del target macOS y firma; un Swift Package local para Core/Storage, Swift 6 language mode y dependencias remotas vacías. SwiftUI y frameworks nativos, SQLite del SDK. Las bibliotecas de soporte de Swift que Xcode deba incorporar forman parte del bundle/plataforma; el usuario no instala Swift, Python, Node, Electron ni otras herramientas.

El mínimo de implementación/MVP aprobado es macOS 14 (2026-09-26); validar de nuevo antes de una futura distribución y no confundir toolchain del desarrollador con OS del usuario. **Apple silicon exclusivamente**, por decisión del propietario del 2026-09-25: generar binario arm64, sin slice x86_64, soporte Intel ni Universal 2. No se necesita Rosetta. Sin dependencias compiladas descargadas por scripts. Build normal posible offline tras instalar herramientas/certificados requeridos; firma/notarización tienen necesidades separadas. El build local se comprobó con Xcode 27/macOS 27 SDK y target 14; el toolchain de release y la identidad/canal de distribución siguen pendientes.

Identidad de bundle y equipo se fija antes del primer uso real de Keychain. Cambiar identidad puede impedir acceso a item/contendor; preservar continuidad de firma en upgrades y probarla. Debug/Test usan identificadores y datos separados. Archive Release con optimización, símbolos externos guardados por el desarrollador para diagnóstico, sin datasets privados ni llaves incluidas.

El uso propuesto de Data Protection Keychain requiere que los grupos de acceso estén autorizados por un perfil de provisioning incorporado al bundle, también en distribución Developer ID. Configurar esto en B; la firma por sí sola no concede cualquier grupo solicitado. Validar continuidad del AppIdentifierPrefix además del bundle ID. [Apple: modelos de acceso Keychain en macOS](https://developer.apple.com/documentation/technotes/tn3137-on-mac-keychains).

## Sandbox, firma y hardened runtime

Sandbox activado también para distribución directa; no es exclusivo de App Store. Entitlements finales según [privacy.md](privacy.md), sin excepciones de red, acceso amplio ni ejecución dinámica. Hardened runtime habilitado y sin get-task-allow en distribución. Inspeccionar firma/entitlements del **archive/export resultante**, no solo `.entitlements` en código fuente.

Distribución directa propuesta: certificado Developer ID Application e identidad estable; no distribuir build ad hoc de depuración como versión final. La firma acredita integridad/identidad, no cifra la DB ni acredita ausencia de vulnerabilidades. Sin helpers privilegiados, launch agents, login item o instalador que pida admin. Copiar a /Applications puede requerir permiso según configuración del Mac; la app se ejecuta como usuario corriente.

## Cadena de publicación

```text
fuente revisada + tests
      -> Xcode Archive Release
      -> export Developer ID + verificación de entitlements
      -> notarización de .app empaquetada
      -> staple ticket en .app y validar
      -> DMG opcional con .app + enlace a /Applications
      -> firmar/notarizar/staple DMG según flujo elegido
      -> probar artefacto descargado/cuarentena y sin red
```

La notarización necesita conexión del **entorno de publicación** con Apple y credenciales del desarrollador. No envía calendarios; el artefacto debe estar libre de datos de usuario. Usar flujo actual de Xcode/notarytool y guardar credenciales fuera del repo. Stapling adjunta ticket y facilita verificación offline; no elimina la capacidad del OS de consultar seguridad/revocación cuando hay red. [Apple: notarización](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution), [personalizar flujo](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

Probar que el ticket acompaña la .app que finalmente se copia, incluso si se extrae del DMG; no asumir que distribuir cualquier ZIP conservará lo necesario. La .app se escribe una vez firmada solo según operaciones soportadas de stapling; no modificar recursos después de firmar. DMG de solo lectura y nombre neutro, sin instaladores auxiliares. [Apple: empaquetado macOS](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution).

## Verificación antes de distribuir

Verificar códigos de firma y políticas Gatekeeper con herramientas de macOS (`codesign`, `spctl`, `stapler`), revisar permisos, frameworks y ausencia de claves/fixtures. Validar lanzamiento desde archivo con cuarentena en cuenta/VM limpia y luego CRUD completo sin red. Comprobar primera instalación, upgrade conservando Keychain/DB, downgrade rechazado y restauración con kit en otra cuenta. No exigir que Gatekeeper se omita para «funcionar offline».

Sin updater integrado: nueva versión distribuida manualmente con firma equivalente. No checks de versiones ni licencias por red al arrancar. La instalación no migra hasta autenticación y copia segura según [database.md](database.md). Eliminar la .app no equivale a borrar contenedor, llavero ni copias; documentar desinstalación cuando exista producto.

## Mac App Store: posibilidad futura

No parte del MVP. Requiere revisar App Review, firma/provisioning, sandbox, declaraciones de privacidad y requisitos vigentes. No añade cuentas de Kansolendar ni sincronización; la tienda y sus descargas son infraestructura del distribuidor/OS. Probar acceso Keychain y contenedor al cambiar de canal antes de prometer migración entre Developer ID y App Store. No compartir grupos por conveniencia.

La ausencia de telemetría no evita revisar APIs con required reasons, por ejemplo ajustes si se usa UserDefaults. Preparar privacy manifest veraz para APIs realmente usadas y requisitos aplicables; sin tracking domains ni SDKs declarados ficticiamente. Verificar normativa técnica vigente al publicar, no fijar hoy una razón inventada. [Apple: privacy manifests](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files).

## Límites de la promesa offline

La aplicación instalada no necesita Internet ni incorpora red. Descargar Xcode, obtener certificados, notarizar, descargar app/updates y funciones propias del OS pueden usarla. Son actividades diferentes, no excepciones escondidas en el calendario. No prometer que el Mac entero nunca se conectará ni que la notarización sea una auditoría de privacidad.
