#!/bin/bash
# Builds build/SuperScreenshot.app (release by default; `--debug` for a fast debug build) and signs it with the
# project-local identity from scripts/signing-setup.sh (falls back to ad-hoc).
#
# DISTRIBUTION=direct (default) is the GitHub/DMG edition, unchanged. DISTRIBUTION=appstore builds the sandboxed Mac App
# Store edition into build/appstore/SuperScreenshot.app: compiled with -DAPP_STORE (no updater), its own bundle id,
# Store entitlements, extensions rebuilt for that id, ad-hoc signed. scripts/package-appstore.sh signs it for real.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"; cd "$ROOT"
CONFIG=release; [ "${1:-}" = "--debug" ] && CONFIG=debug
DISTRIBUTION="${DISTRIBUTION:-direct}"
# The App Store edition's bundle id: change it here before registering the app in App Store Connect.
APPSTORE_BUNDLE_ID=com.udsy.superscreenshot.appstore

SWIFT_FLAGS=(); OUT="$ROOT/build"
case "$DISTRIBUTION" in
  direct) ;;
  appstore)
    # Separate scratch path so switching editions doesn't rebuild everything.
    SWIFT_FLAGS=(--scratch-path "$ROOT/.build-appstore" -Xswiftc -DAPP_STORE); OUT="$ROOT/build/appstore"
    APP_ID="$APPSTORE_BUNDLE_ID" PLUGINS_DIR="$OUT/PlugIns" ./scripts/build-extensions.sh ;;
  *) echo "DISTRIBUTION must be direct or appstore (got '$DISTRIBUTION')" >&2; exit 2 ;;
esac
sb() { swift build -c "$CONFIG" ${SWIFT_FLAGS[@]+"${SWIFT_FLAGS[@]}"} "$@"; }
if [ "${UNIVERSAL:-0}" = 1 ]; then
  # Build each architecture separately (the CLT toolchain has no multi-arch build) and merge with lipo.
  for arch in arm64 x86_64; do sb --product SuperScreenshot --triple "$arch-apple-macosx14.0"; done
  BIN="$OUT/universal"; mkdir -p "$BIN"
  lipo -create -output "$BIN/SuperScreenshot" "$(sb --triple arm64-apple-macosx14.0 --show-bin-path)/SuperScreenshot" "$(sb --triple x86_64-apple-macosx14.0 --show-bin-path)/SuperScreenshot"
else
  sb --product SuperScreenshot
  BIN="$(sb --show-bin-path)"
fi

APP="$OUT/SuperScreenshot.app"
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/SuperScreenshot" "$APP/Contents/MacOS/SuperScreenshot"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
# SwiftPM resource bundles (if any module declares resources).
find "$BIN" -maxdepth 1 -name '*.bundle' -exec cp -R {} "$APP/Contents/Resources/" \;
# Extensions built by scripts/build-extensions.sh, if present.
[ -d "$OUT/PlugIns" ] && cp -R "$OUT/PlugIns" "$APP/Contents/PlugIns"

ICONSET="$ROOT/build/AppIcon.iconset"
if [ ! -f "$ROOT/build/AppIcon.icns" ]; then
  swift "$ROOT/scripts/make-icon.swift" "$ICONSET" && iconutil -c icns "$ICONSET" -o "$ROOT/build/AppIcon.icns"
fi
cp "$ROOT/build/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

if [ "$DISTRIBUTION" = appstore ]; then
  PB=/usr/libexec/PlistBuddy
  $PB -c "Set :CFBundleIdentifier $APPSTORE_BUNDLE_ID" "$APP/Contents/Info.plist"
  $PB -c "Set :CFBundleURLTypes:0:CFBundleURLName $APPSTORE_BUNDLE_ID" "$APP/Contents/Info.plist"
  $PB -c "Delete :NSAppleEventsUsageDescription" "$APP/Contents/Info.plist"   # no Apple Events in this edition
  # HTTPS (uploads) only uses the OS's encryption: exempt from export documentation.
  $PB -c "Add :ITSAppUsesNonExemptEncryption bool false" "$APP/Contents/Info.plist"
  xattr -cr "$APP"   # quarantine/Finder attributes break App Store uploads
  # Ad-hoc signature, inside-out, so the sandbox is enforced when run locally.
  [ -d "$APP/Contents/PlugIns" ] && for ext in "$APP"/Contents/PlugIns/*.appex; do
    codesign -f -s - --entitlements "$ROOT/Resources/Extension.entitlements" "$ext"
  done
  codesign -f -s - --entitlements "$ROOT/Resources/SuperScreenshot-AppStore.entitlements" "$APP"
  echo "Built $APP (App Store edition, ad-hoc signed)"; exit 0
fi

KC="$ROOT/.signing/superscreenshot.keychain-db"
ENT="$ROOT/Resources/SuperScreenshot.entitlements"
if [ -f "$KC" ]; then
  security unlock-keychain -p superscreenshot "$KC"
  ORIG=()
  while IFS= read -r line; do line="${line#"${line%%[![:space:]]*}"}"; line="${line//\"/}"; [ -n "$line" ] && ORIG+=("$line"); done < <(security list-keychains -d user)
  restore() { security list-keychains -d user -s "${ORIG[@]}"; }
  trap restore EXIT
  security list-keychains -d user -s "${ORIG[@]}" "$KC"
  [ -d "$APP/Contents/PlugIns" ] && for ext in "$APP"/Contents/PlugIns/*.appex; do
    codesign -f -s "Super Screenshot Local Signing" --keychain "$KC" -o runtime --entitlements "$ROOT/Resources/Extension.entitlements" "$ext"
  done
  codesign -f -s "Super Screenshot Local Signing" --keychain "$KC" -o runtime --entitlements "$ENT" "$APP"
  restore; trap - EXIT
else
  codesign -f -s - --entitlements "$ENT" "$APP"
fi
echo "Built $APP"
