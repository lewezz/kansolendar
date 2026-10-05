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
download channel. Local DMG and ZIP assets with SHA-256 checksums are prepared
under `.build/ReleaseAssets/`; publication is a separate user-authorized action.

Installation and per-app first-open instructions are in [README](../README.md).
Do not disable Gatekeeper globally. Managed machines may prevent exceptions.
Fresh-Mac quarantined-download launch, Finder association and sandboxed saving
need integration validation before claiming a distributable release. See
[testing](testing.md).

## Local release assets

The DMG presents `Kansolendar.app` and an `Applications` shortcut targeting
`/Applications`. Drag the app onto the shortcut, eject the image, and open the
installed copy. It is a compressed, read-only HFS+ disk image created with the
native `hdiutil` tool from the existing app; packaging does not rebuild, install,
launch or change the app's signature. It does not replace the first-open approval
described in the README.

The alternative ZIP contains only `Kansolendar.app`, created with `ditto -c -k
--sequesterRsrc --keepParent` to preserve bundle resources and signing. Release
filenames use the chosen release label, such as `kansolendar-1.0v.dmg` and
`kansolendar-1.0v.zip`; the app's supported architecture remains arm64.

Verify the adjacent `.sha256` file with `shasum -a 256 -c <asset>.sha256` from the
asset directory. Verify the disk image or extract the ZIP, inspect its contents,
and verify the packaged application signature before upload. Source ZIPs,
`.kanso` files, test fixtures and development logs are not app release assets.
