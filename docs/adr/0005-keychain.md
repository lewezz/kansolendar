# ADR-0005 — Clave local de bóveda, desbloqueo del sistema y recuperación separada

## Context

Guardar una clave junto a DB anula la protección ante copia. También es peligroso depender de una clave que el usuario pueda perder sin entenderlo. macOS tiene variantes de Keychain que deben distinguirse. Kansolendar no tendrá cuentas, identidad de producto, login, servidor, ni una contraseña de cuenta.

## Decision

Al crear una bóveda, Kansolendar genera una DEK aleatoria de 32 bytes exclusiva para esa bóveda. La DEK cifra los contenidos; no es una credencial de usuario ni se deriva de Touch ID. En el dispositivo, guardar la DEK en Data Protection Keychain como generic password, no sincronizable, `WhenUnlockedThisDeviceOnly` y ACL `userPresence`, con identidad propia de la app firmada. Touch ID (o el mecanismo local que macOS permita) autoriza el acceso al secreto. No crear un flujo de cuenta/login ni pedir una contraseña de Kansolendar en el MVP. Una exportación de recuperación explícita y separada contiene la DEK y permite recuperar los datos; no se crea automáticamente. La DEK solo permanece disponible en memoria durante una sesión desbloqueada.

## Alternatives

Archivo de clave junto a la DB o UserDefaults: rechazados. Clave hardcodeada: rechazada. Biometría obligatoria excluye equipos y complica recuperación; por eso la política es `userPresence`, no Touch ID exclusivo. Contraseña propia sería un modo de desbloqueo distinto, con KDF resistente a ataques de diccionario, UX y recuperación específicos; queda fuera del MVP. Sin recuperación maximiza sencillez pero hace pérdida/migración mucho más peligrosa.

## Consequences

Quien pueda satisfacer la autenticación local de macOS puede desbloquear el item; no es un factor independiente ni un login de Kansolendar. Kit + DB permiten descifrar. Sin item/kit, datos irrecuperables. Este diseño no garantiza que Keychain migre a otro Mac; probar restores por kit. No fallback silencioso si ACL falla en plataforma admitida. La firma de desarrollo de Xcode es una precondición de validación del Data Protection Keychain, no una cuenta requerida por la app instalada.

## Status

Aceptado por el propietario: bóveda sin cuenta/login y desbloqueo local mediante Touch ID o mecanismo de presencia de macOS; Kansolendar crea una clave aleatoria exclusiva por bóveda, con recuperación exportable separada. La aclaración se confirmó el 2026-09-26. La prueba actual falla con `errSecMissingEntitlement` en firma ad hoc; por tanto, el comportamiento del Data Protection Keychain aún no está probado. La firma Apple Development es solo una herramienta posible para validar el entitlement y no añade autenticación de cuenta al producto. Los atributos/ACL, UX y restauración siguen sujetos a los gates técnicos. Ver [gestión de claves](../key-management.md).
