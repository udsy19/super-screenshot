# Known blockers

## Credential-gated (cannot be done in this session)
- No Apple Distribution or 3rd Party Mac Developer Installer identities, and no provisioning profiles. That means no real signing, `.pkg` creation, validation or upload.
- Before packaging, register App IDs in App Store Connect for `com.udsy.superscreenshot.appstore` and its four extension ids (or change `APPSTORE_BUNDLE_ID` in `scripts/build-app.sh` first).
- `altool` and `xcodebuild` are not installed; upload with Transporter.

## Needs a human run (TCC or GUI)
- Run `scripts/e2e.sh` on the direct build. For the Store build, grant Screen Recording to `build/appstore/SuperScreenshot.app` and repeat the URL-scheme checks. Set `SUPERSCREENSHOT_BUNDLE_ID=com.udsy.superscreenshot.appstore` for `Tools/e2e/ui`, and note that `filepath=` parameters must point inside the container or a granted folder.
- Recording with mic, system audio and camera after granting; confirm which microphone entitlement key is the one checked.
- Scrolling-capture auto-scroll after granting Accessibility (CGEvent posting from the sandbox).
- Studio Mode click tracking and the keystroke overlay with Input Monitoring granted (the event tap).
- Choose an export folder → quit → relaunch → save a capture there (bookmark persistence).
- Share menu → "Annotate with Super Screenshot" / "Pin to the Screen" from Finder or Photos (named-pasteboard write from the sandboxed extension).
- Import flow, settings step: select `com.udsy.superscreenshot.plist` in the second panel.
- Check whether the Accessibility prompt appears from the sandbox (`universalaccessAuthWarn` mach-lookup denial on first launch).

## Material product changes needing owner approval
1. The Store edition saves to **`~/Pictures/Super Screenshot`** by default, not the Desktop. A Desktop default would need a user pick or a temporary-exception entitlement.
2. URL-scheme `filepath=` parameters (Raycast and Alfred automations) only work for files the app can already reach.
3. Without Input Monitoring, global Esc and keystroke display don't work in the Store build (previously these were covered by Accessibility).
4. There are no in-app updates in the Store edition (the App Store handles them).

## Review risks
- **SCContentSharingPicker**: Apple recommends the system picker. The app uses its own selection UI on top of ScreenCaptureKit, because area selection isn't possible with the picker. If review objects, explain in review notes.
- **Accessibility and event posting** for auto-scroll, plus **Input Monitoring** for the keystroke overlay, could be questioned under 2.4.5. Both are optional and off the main path.
- **Naming**: the About pane and README call the app a "reimplementation of the CleanShot X feature set". Referencing a competitor's name in the app or metadata may conflict with guideline 2.3.7 or 5.2. The owner should reword this for the Store build.
- The direct and Store editions share the `superscreenshot://` scheme.
