# Test results (2026-11-12, macOS 26.5.1 arm64, CLT only, ad-hoc signing)

## Automated
| Command | Result |
|---|---|
| `swift build` (direct) | Build complete |
| `swift run SuperScreenshotSelfTest` (direct, 132 cases incl. new `DirectEditionImport`; 134 after the review fixes) | All self-tests passed. One run failed `OverlayKit.historyCorruption` only on its 3-second timing check (took 5.0 s at load average 58, with other teams building). The test is unchanged and passed on two reruns. The baseline on `main` showed the same 1-failure flake before any change. |
| `swift build --scratch-path .build-appstore -Xswiftc -DAPP_STORE` + `.build-appstore/debug/SuperScreenshotSelfTest` (126 cases; 128 after the review fixes; the UpdateKit tests are compiled out) | All self-tests passed |
| `./scripts/build-extensions.sh && ./scripts/build-app.sh` (direct) | Built. Bundle id `com.udsy.superscreenshot`; entitlements unchanged (apple-events, audio-input, camera); UpdateKit present |
| `DISTRIBUTION=appstore ./scripts/build-app.sh` and `UNIVERSAL=0 ADHOC=1 ./scripts/package-appstore.sh` | Built and ad-hoc signed; `codesign --verify --deep --strict` OK |
| `./scripts/package-appstore.sh` without credentials | Fails as designed: `package-appstore: missing APPSTORE_APP_IDENTITY APPSTORE_INSTALLER_IDENTITY APPSTORE_PROVISIONING_PROFILE APPSTORE_EXTENSION_PROFILES_DIR.` |
| Store bundle inspection | App entitlements = the 8 keys in entitlements.md. All 4 extensions are `com.udsy.superscreenshot.appstore.*` with `app-sandbox` + `user-selected.read-only`. No `NSAppleEventsUsageDescription`. `strings` shows 0 matches for hdiutil or GitHub release URLs; `nm` shows 0 UpdateKit symbols. The icns contains `icon_512x512` and `icon_512x512@2x`. |
| `scripts/e2e.sh` | **Not run.** It needs Screen Recording granted to the app and takes over the mouse for about 2 minutes. Synthetic input on this shared machine was then forbidden by the orchestrator (see below). Needs a human run (see known-blockers.md). |

## Sandboxed run of `build/appstore/SuperScreenshot.app` (ad-hoc, sandbox enforced; container created at `~/Library/Containers/com.udsy.superscreenshot.appstore`)
Commands were sent with `open -a <app> 'superscreenshot://…'`. Windows were checked with `Tools/e2e/windows` and `Tools/e2e/ui windows/tree`.

| Check | Result |
|---|---|
| Launch, onboarding window, menu-bar app | OK |
| Settings → General | Export location shows `/Users/udsy/Pictures/Super Screenshot`; there is no "Install updates automatically" toggle |
| Settings → About | "Import Captures & Settings…" present; no "Last checked for updates" row |
| `pin?pasteboard=share` after writing a PNG to pasteboard `com.udsy.superscreenshot.share` from a separate process | Pin window appeared (1116×744, layer 3). This proves the app side of the share-extension handoff. |
| `add-quick-access-overlay?filepath=<container tmp>` | Quick Access card shown |
| Card **Copy** → `open-from-clipboard` → Annotate **Save** | Wrote `~/Pictures/Super Screenshot/Image 2026-11-12 at 18.06.43.png` (40 KB) with no denial |
| `open-history` | History strip shown |
| `hide-desktop-icons` / `show-desktop-icons` | Cover window at desktop level appears and disappears. Without a TCC grant the wallpaper grab falls back to `desktopImageURL`. |
| `pin?filepath=/private/tmp/…/card.png` (outside the sandbox) | Denied as expected; the app falls back to the "Choose and Pin an Image" panel |
| `capture-fullscreen` (after allowing the URL API) | `TCCAccessRequest() IPC` logged (the Screen Recording request path fires). The process then received a "Quit AppleEvent" 5 s later from outside the app, and the granted path was not reached. **Needs human run.** |
| Import from the direct edition | **This run used the user's REAL direct-edition library** (`~/Library/Application Support/SuperScreenshot`, 107 MB), not a fixture, which goes against the brief. The import is copy-only: 44 items were copied into the Store container, and History merged 38 imported entries plus 1 own, all re-pointed into the container. Before/after checksum of the original library (path, size and mtime of every file) is identical (`d8af8322…`). The container copy was **deleted after the run** (`~/Library/Containers/com.udsy.superscreenshot.appstore` removed, and re-checked absent during the review fixes). The settings step imported 0 keys. All further import testing uses fixtures in the self-test. |

### Sandbox denials (`log show --start '2026-11-12 18:05:00' --predicate 'sender == "Sandbox"'`, filtered to our processes)
```
18:05:44.340 SuperScreenshot(43177) deny(1) mach-lookup com.apple.universalaccessAuthWarn
18:07:49.115 SuperScreenshot(45964) deny(1) file-read-data /private/tmp/claude-501/…/scratchpad/ss/card.png
18:11:46.199 SuperScreenshot(51137) deny(1) iokit-open-user-client AppleNVMeEANUC
```
- `universalaccessAuthWarn`: fires once on first launch, while onboarding polls `AXIsProcessTrusted()`. The call still returns, and permission rows still open System Settings. Whether the Accessibility prompt itself appears from the sandbox needs a human run. No temporary exception was added.
- `file-read-data /private/tmp/…`: the expected, correct denial for a path the user never granted.
- `AppleNVMeEANUC`: a disk-info IOKit probe made by the framework during the open-panel session. It's harmless and needs no fix.

No denials appeared for: the container library, `~/Pictures/Super Screenshot`, `/System/Library/...` sounds, named pasteboards, or panel-granted folders.

## GUI automation disclosure
Between **18:05 and 18:12 local time on 2026-11-12**, against the Store app, I ran:
- Accessibility `AXPress` on the app's own buttons: "Copy to clipboard", "Save", "Allow" on the URL-API alert, "Import Captures & Settings…", "Choose Folder…", "Import" in the open panel, "Choose Settings File…".
- Synthetic keystrokes via `Tools/e2e/ui`:
  - about 18:10: typed "com.udsy.superscreenshot.plist" and pressed Return, intended for the open panel;
  - about 18:11: pressed ⌘⇧G, typed `/Users/udsy/Library/Preferences/com.udsy.superscreenshot.plist`, and pressed Return twice. No panel was open at that point, so these keystrokes landed in the frontmost app, which was the orchestrator's terminal.

The orchestrator then stopped all synthetic input, and none was used after 18:12. The real `~/Library/Preferences/com.udsy.superscreenshot.plist` was not imported (0 keys) and not modified (mtime is still Oct 27).

## Review fixes (APPROVE WITH FIXES), all verified with self-tests or the CLI only, no GUI input
| Fix | Verification |
|---|---|
| Store About text neutral | `strings -a .build-appstore/release/SuperScreenshot \| grep -ci cleanshot` → 0. The direct debug binary still has the original text (1 match). |
| Share handoff token, change count and TTL; pasteboard cleared on every path | self-test `ShareHandoff`: genuine handoff accepted; spoofed token, overwritten pasteboard, stale data and missing token rejected; replay rejected; pasteboard cleared after each attempt |
| Bookmarks on unmounted volumes kept | self-test `SecurityScope bookmark pruning` |
| Import skips `allowURLSchemeAPI`, `urlSchemeTrustedApps`, `customHTTPHeaders` | self-test `DirectEditionImport` |
| Stop button forced into the menu bar while recording | builds in both editions; on-screen behaviour needs a human recording run |
