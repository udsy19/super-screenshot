#!/bin/bash
# Signs the App Store edition (build/appstore/SuperScreenshot.app from DISTRIBUTION=appstore build-app.sh) inside-out
# and wraps it in an installer package for App Store Connect:
#
#   APPSTORE_APP_IDENTITY="Apple Distribution: NAME (TEAMID)"
#   APPSTORE_INSTALLER_IDENTITY="3rd Party Mac Developer Installer: NAME (TEAMID)"
#   APPSTORE_PROVISIONING_PROFILE=/path/to/SuperScreenshot_AppStore.provisionprofile        (the app's Mac App Store profile)
#   APPSTORE_EXTENSION_PROFILES_DIR=/path/to/dir   (one <extension bundle id>.provisionprofile per extension)
#   ./scripts/package-appstore.sh            → dist/SuperScreenshot-<version>-AppStore.pkg
#
#   ADHOC=1 ./scripts/package-appstore.sh    → ad-hoc signed, sandboxed .app for local testing (no .pkg)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
PB=/usr/libexec/PlistBuddy

if [ "${ADHOC:-0}" != 1 ]; then
  missing=()
  [ -n "${APPSTORE_APP_IDENTITY:-}" ] || missing+=(APPSTORE_APP_IDENTITY)
  [ -n "${APPSTORE_INSTALLER_IDENTITY:-}" ] || missing+=(APPSTORE_INSTALLER_IDENTITY)
  [ -f "${APPSTORE_PROVISIONING_PROFILE:-}" ] || missing+=(APPSTORE_PROVISIONING_PROFILE)
  [ -d "${APPSTORE_EXTENSION_PROFILES_DIR:-}" ] || missing+=(APPSTORE_EXTENSION_PROFILES_DIR)
  if [ ${#missing[@]} -gt 0 ]; then
    echo "package-appstore: missing ${missing[*]}." >&2
    echo "Needs an Apple Distribution (or 3rd Party Mac Developer Application) identity, a 3rd Party Mac Developer Installer" >&2
    echo "identity in the keychain, and Mac App Store provisioning profiles for the app and each extension. See docs/app-store/README.md." >&2
    echo "For a local sandboxed test build run: ADHOC=1 $0" >&2
    exit 1
  fi
fi

UNIVERSAL="${UNIVERSAL:-1}" DISTRIBUTION=appstore ./scripts/build-app.sh
APP="$ROOT/build/appstore/SuperScreenshot.app"
VERSION=$($PB -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
WORK="$(mktemp -d -t superscreenshot-appstore)"; trap 'rm -rf "$WORK"' EXIT

if [ "${ADHOC:-0}" = 1 ]; then
  echo "Ad-hoc signed sandboxed build: $APP"
  codesign -d --entitlements - "$APP" 2>/dev/null | sed -n '1,40p'
  exit 0
fi

# entitlements_for <base entitlements> <profile> <out>: base + the profile's application identifier and team.
entitlements_for() {
  security cms -D -i "$2" > "$WORK/profile.plist"
  cp "$1" "$3"
  local appid team
  appid=$($PB -c "Print :Entitlements:com.apple.application-identifier" "$WORK/profile.plist")
  team=$($PB -c "Print :Entitlements:com.apple.developer.team-identifier" "$WORK/profile.plist")
  $PB -c "Add :com.apple.application-identifier string $appid" "$3"
  $PB -c "Add :com.apple.developer.team-identifier string $team" "$3"
}

xattr -cr "$APP"
for ext in "$APP"/Contents/PlugIns/*.appex; do
  id=$($PB -c "Print CFBundleIdentifier" "$ext/Contents/Info.plist")
  profile="$APPSTORE_EXTENSION_PROFILES_DIR/$id.provisionprofile"
  [ -f "$profile" ] || { echo "package-appstore: missing $profile" >&2; exit 1; }
  cp "$profile" "$ext/Contents/embedded.provisionprofile"
  entitlements_for "$ROOT/Resources/Extension.entitlements" "$profile" "$WORK/$id.entitlements"
  codesign -f -s "$APPSTORE_APP_IDENTITY" --entitlements "$WORK/$id.entitlements" "$ext"
done
cp "$APPSTORE_PROVISIONING_PROFILE" "$APP/Contents/embedded.provisionprofile"
entitlements_for "$ROOT/Resources/SuperScreenshot-AppStore.entitlements" "$APPSTORE_PROVISIONING_PROFILE" "$WORK/app.entitlements"
codesign -f -s "$APPSTORE_APP_IDENTITY" --entitlements "$WORK/app.entitlements" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

mkdir -p dist
PKG="dist/SuperScreenshot-$VERSION-AppStore.pkg"
productbuild --component "$APP" /Applications --sign "$APPSTORE_INSTALLER_IDENTITY" "$PKG"
echo "Built $PKG — upload with Transporter or: xcrun altool --upload-app -f $PKG -t macos (needs Xcode)"
