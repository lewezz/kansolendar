# Distribution

There is one Kansolendar app target and shared scheme. It targets arm64 and
macOS 14+, uses manual ad hoc signing (`CODE_SIGN_IDENTITY = -`), no development
team or temporary provisioning profile, and no paid developer membership.
Both app configurations use the same product, not an alternate distribution app.

`bash scripts/build.sh` builds Release and verifies the signature, architecture,
absence of provisioning profiles/certificate authorities, absence of debug/network/
Keychain-group entitlements, and the sandbox. It produces
`.build/Latest/Build/Products/Release/Kansolendar.app`; no installation, launch,
archive publication or GitHub upload occurs automatically.

Ad hoc signatures have no certificate expiration or seven-day development profile.
This is independent of Gatekeeper acceptance, OS compatibility and future security
policy. The app is not Developer ID signed or notarized. GitHub is the intended
download channel; no release was published by this implementation.

Installation and per-app first-open instructions are in [README](../README.md).
Do not disable Gatekeeper globally. Managed machines may prevent exceptions.
Fresh-Mac quarantined-download launch, Finder association and sandboxed saving
need integration validation before claiming a distributable release. See
[testing](testing.md).
