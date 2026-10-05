#!/usr/bin/env bash
set -euo pipefail

# One standard app artifact. No Apple account, certificate or provisioning profile.
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
BUILD_OUTPUT="$PROJECT_ROOT/.build/Latest"
xcodebuild -project "$PROJECT_ROOT/Kansolendar.xcodeproj" -scheme Kansolendar \
    -configuration Release -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$BUILD_OUTPUT" build

APP_OUTPUT="$BUILD_OUTPUT/Build/Products/Release/Kansolendar.app"
codesign --verify --deep --strict "$APP_OUTPUT"
python3 - "$APP_OUTPUT" <<'PY'
from pathlib import Path
import plistlib
import subprocess
import sys

app = Path(sys.argv[1])
assert not list(app.rglob('*.provisionprofile')), 'Temporary provisioning profile found'
assert not list(app.rglob('*.mobileprovision')), 'Temporary provisioning profile found'
details = subprocess.run(['codesign', '-dv', '--verbose=2', str(app)], capture_output=True, text=True, check=True).stderr
assert 'Signature=adhoc' in details and 'Authority=' not in details, 'Certificate-backed signature found'
entitlements = plistlib.loads(subprocess.check_output(['codesign', '-d', '--entitlements', ':-', str(app)], stderr=subprocess.DEVNULL))
assert entitlements.get('com.apple.security.app-sandbox') is True
for forbidden in ('keychain-access-groups', 'com.apple.security.get-task-allow', 'com.apple.security.network.client', 'com.apple.security.network.server'):
    assert not entitlements.get(forbidden), f'Unexpected entitlement: {forbidden}'
architectures = subprocess.check_output(['lipo', '-archs', str(app / 'Contents/MacOS/Kansolendar')], text=True).strip()
assert architectures == 'arm64', architectures
print(f'Verified ad hoc arm64 app with no development profile: {app}')
PY
