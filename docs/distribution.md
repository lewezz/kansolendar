# Application and distribution status

## Current project

The repository contains one macOS app target and one shared scheme, both named
`Kansolendar`, plus the local KansolendarKit package. Debug and Release are
configured for arm64, Swift 6, automatic Apple Development signing, and the
`local.kansolendar.development` bundle identifier. The deployment target is macOS
14.0. These are project settings, not evidence of an installable release.

The app has no bundled external runtime, remote package dependency, installer,
background helper, updater, or network entitlement. Its `.kanso` document type is
registered in [Info.plist](../Kansolendar/Info.plist).

## Requested delivery

GitHub is the user's requested distribution channel. Packaging, publishing,
release signing identity, update delivery, and fresh-Mac launch behavior are not
established in the current repository. No published-download or permanent-launch
guarantee is made by these docs. The name Release does not turn the current
development-signing configuration into a verified distribution artifact.

Earlier architecture notes proposed a different publication process. That
proposal is historical, not an implemented or approved release pipeline. There
is no alternate application variant or parallel distribution configuration.

## Outstanding validation

A requested release needs a concrete packaging/identity decision and verification
of the resulting artifact on a clean supported Mac, including document association,
sandbox access, local Keychain behavior, and upgrade continuity. Portable vaults
carry their own wrapped key; the legacy local vault still depends on its app's
Keychain identity.

No build, signing, packaging, notarization, GitHub upload, or app launch was run
as part of this documentation revision. Delivery actions require a separate
explicit request. See [testing](testing.md) and [ADR-0012](adr/0012-distribution.md).
