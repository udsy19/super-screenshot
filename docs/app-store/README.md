# Super Screenshot: Mac App Store edition

**Status: FUNCTIONAL VALIDATION PENDING.** The code is done. Real signing and upload are blocked on credentials (there are no signing identities or provisioning profiles on this Mac). Every feature that needs Screen Recording, Microphone, Camera, Accessibility or Input Monitoring permission still needs a person to grant the permission and run it.

The repo builds two editions from one codebase:

| | Direct (GitHub/DMG) | App Store |
|---|---|---|
| Build | `./scripts/build-app.sh` (unchanged) | `DISTRIBUTION=appstore ./scripts/build-app.sh` |
| Compile flag | none | `-DAPP_STORE` (scratch path `.build-appstore`) |
| Bundle id | `com.udsy.superscreenshot` | `com.udsy.superscreenshot.appstore` (the `APPSTORE_BUNDLE_ID` variable in `scripts/build-app.sh`) |
| Output | `build/SuperScreenshot.app` | `build/appstore/SuperScreenshot.app` |
| Sandbox | no | yes (`Resources/SuperScreenshot-AppStore.entitlements`) |
| Updater | UpdateKit (GitHub Releases) | not compiled in |
| Apple Events entitlement | yes | no |

## Commands
```bash
swift build && swift run SuperScreenshotSelfTest                                   # direct self-tests
swift build --scratch-path .build-appstore -Xswiftc -DAPP_STORE \
  && .build-appstore/debug/SuperScreenshotSelfTest                                 # Store-flag self-tests
DISTRIBUTION=appstore ./scripts/build-app.sh                                       # ad-hoc signed sandboxed .app
UNIVERSAL=0 ADHOC=1 ./scripts/package-appstore.sh                                  # same, via the packaging script
# Real submission package (needs credentials):
APPSTORE_APP_IDENTITY="Apple Distribution: NAME (TEAMID)" \
APPSTORE_INSTALLER_IDENTITY="3rd Party Mac Developer Installer: NAME (TEAMID)" \
APPSTORE_PROVISIONING_PROFILE=~/profiles/SuperScreenshot_AppStore.provisionprofile \
APPSTORE_EXTENSION_PROFILES_DIR=~/profiles/extensions \
./scripts/package-appstore.sh        # → dist/SuperScreenshot-<version>-AppStore.pkg (universal)
```
The extension profiles directory holds one `<bundle id>.provisionprofile` for each of `com.udsy.superscreenshot.appstore.{AnnotateShareExtension,PinShareExtension,QuickLookExtension,QuickLookThumbnailingExtension}`.

Upload the `.pkg` with Transporter. `altool` needs Xcode, which isn't installed here.

## Other documents
[compliance-matrix](compliance-matrix.md) · [architecture](architecture.md) · [entitlements](entitlements.md) · [privacy-and-permissions](privacy-and-permissions.md) · [dependency-and-license-audit](dependency-and-license-audit.md) · [test-results](test-results.md) · [app-store-connect](app-store-connect.md) · [review-notes](review-notes.md) · [known-blockers](known-blockers.md) · [inventory.json](inventory.json)

There is no `model-and-asset-strategy.md` because the app downloads nothing after install. The only network use is uploads the user configures, and the Store edition has no updater.
