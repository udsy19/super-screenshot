# Architecture of the App Store edition

The Store edition is the same SwiftPM package compiled with `-DAPP_STORE`. Every difference is listed below.

## Build and packaging
- `scripts/build-app.sh` with `DISTRIBUTION=appstore` does these steps:
  1. Builds into `.build-appstore` with `-Xswiftc -DAPP_STORE`.
  2. Rebuilds the four extensions into `build/appstore/PlugIns`. Their bundle ids are `com.udsy.superscreenshot.appstore.<Name>` and they are compiled with `-D APP_STORE`.
  3. Rewrites the bundle id and the URL-type name, removes `NSAppleEventsUsageDescription`, and adds `ITSAppUsesNonExemptEncryption=false`.
  4. Runs `xattr -cr`, then ad-hoc signs inside-out: the extensions get `Extension.entitlements`, the app gets `SuperScreenshot-AppStore.entitlements`.
- `scripts/package-appstore.sh` does these steps:
  1. Embeds `embedded.provisionprofile` in the app and in each extension.
  2. Merges `com.apple.application-identifier` and `com.apple.developer.team-identifier` from each profile into that bundle's entitlements.
  3. Signs inside-out with the Apple Distribution identity and runs `codesign --verify --deep --strict`.
  4. Runs `productbuild --component … /Applications --sign <installer>`.

  If any credential is missing, it fails and names the missing variable.
- The extensions now carry the app's `CFBundleShortVersionString` and `CFBundleVersion`. This applies to both editions, because App Store validation rejects extension versions that don't match the app.
- There are no helper executables and no `Process()` calls in the Store binary. The only `Process` use was in UpdateKit (`hdiutil` and `ditto`), and UpdateKit is compiled out.

## Differences in code (`#if APP_STORE` or runtime sandbox check)
| Area | Direct | Store |
|---|---|---|
| Updater | `UpdateKit` (GitHub feed, DMG download, swap on quit) | Each UpdateKit source file is wrapped in `#if !APP_STORE`. Its call sites in `AppDelegate` and `StatusMenuController`, the "Install updates automatically" toggle and the "Last checked" row are compiled out. `nm` and `strings` find no UpdateKit symbols, `hdiutil`, or GitHub URL in the Store binary. |
| Default export folder | `~/Desktop` | `~/Pictures/Super Screenshot`, built from the real home folder (`SecurityScope.realHome`) and covered by `assets.pictures.read-write` |
| User-chosen locations | plain paths | `SecurityScope.remember(url)` stores app-scope security-scoped bookmarks for: folder and image pickers in Settings (export folder, upload folder, custom wallpaper), Save As destinations, recent Annotate projects, and Annotate background images. `SecurityScope.restoreAll()` reopens them at launch and holds access for the process lifetime (intentional). It drops only bookmarks whose target is missing on a mounted volume; bookmarks on unmounted volumes are kept. Outside the sandbox these calls do nothing. |
| Global key and mouse monitoring (Esc to cancel, keystroke overlay, Studio click tracking, closing History by clicking outside) | `NSEvent.addGlobalMonitorForEvents` | `GlobalEvents.monitor` creates a listen-only `CGEventTap` (`ListenOnlyEventTap`). Key events need Input Monitoring (`CGPreflightListenEventAccess` / `CGRequestListenEventAccess`). |
| Auto-scroll in scrolling capture (synthetic scroll events) | `CGPreflightPostEventAccess` (both editions now; previously `AXIsProcessTrusted`) | same |
| Share extensions → app | writes a temp file and opens `superscreenshot://pin?filepath=…` | Puts the PNG, a one-time random token and a timestamp on the named pasteboard `com.udsy.superscreenshot.share`, then opens `superscreenshot://<cmd>?pasteboard=share&token=…&change=<changeCount>` with the containing app explicitly (the direct edition may own the scheme too). The app (`ShareHandoff.take`) accepts only a matching token, an unchanged change count and data under 30 s old. It clears the pasteboard on every attempt; the extension also clears it if the app fails to open. App groups were not used because they need a team-prefixed id and a provisioning profile, which ad-hoc builds don't have. Limit: named pasteboards are readable by any local process while the image is in transit. |
| Recording indicator | menu-bar stop button only if the menu-bar icon is enabled | Both editions: the stop button is always shown in the menu bar while recording. |
| Data import | n/a | Settings → About → **Import Captures & Settings…** (`DirectEditionImport`). Open panels pre-pointed at `~/Library/Application Support/SuperScreenshot` and `~/Library/Preferences/com.udsy.superscreenshot.plist`. The library is copied (`LegacyMigration.merge(copying:)`, skipping `Updates/`). History entries are merged into the live History (`HistoryServicing.merge(indexAt:)`) and paths are re-pointed into the container. Settings are imported except folder paths, login item, updater keys, URL-scheme consent (`allowURLSchemeAPI`, `urlSchemeTrustedApps`) and `customHTTPHeaders` (may hold credentials). The direct edition's files are never changed. |
| Apple Events | entitlement plus usage string (it is only used to receive `kAEGetURL`, which needs no entitlement) | both removed |

## Capture stack
Every pixel capture already goes through ScreenCaptureKit (`SCScreenshotManager`, `SCStream`). Nothing uses `CGWindowListCreateImage`, `CGDisplayCreateImage`, or the `screencapture` CLI. `CGWindowListCopyWindowInfo` is used for window metadata only (hover highlighting), which is allowed in the sandbox. Apple recommends the system content-sharing picker (`SCContentSharingPicker`). We kept the app's own area and window selection UI on top of ScreenCaptureKit, because the picker can't select an arbitrary area. This is recorded as a review risk.

## Coexistence
The two editions have different bundle ids, containers and preference domains. They share the `superscreenshot://` URL scheme. If both are installed, LaunchServices picks one for external callers, so the Store share extensions address their own app directly. TCC grants don't carry over between editions.
