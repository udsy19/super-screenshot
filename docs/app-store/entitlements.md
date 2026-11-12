# Entitlements

## Main app (Store): `Resources/SuperScreenshot-AppStore.entitlements`
| Key | Why |
|---|---|
| `app-sandbox` | Required for the Mac App Store. |
| `files.user-selected.read-write` | Lets the user choose export and upload folders, open images and projects, and Save As. |
| `files.bookmarks.app-scope` | Keeps access to the folders and files the user chose across launches (`SecurityScope`). |
| `assets.pictures.read-write` | Default save folder `~/Pictures/Super Screenshot`. Saving captures somewhere visible without asking first is the app's core job; the alternative would be a picker on first save. |
| `device.audio-input` | Microphone in screen recordings (opt-in per recording). |
| `device.microphone` | Added per orchestrator addendum #10 until an experiment shows which of the two microphone keys is checked. |
| `device.camera` | Camera overlay during recordings (opt-in). |
| `network.client` | User-configured uploads (S3-compatible, custom HTTP). |

Deliberately left out:
- `automation.apple-events`: the app only receives `kAEGetURL`, which needs no entitlement.
- `network.server`, `inherit`, `disable-library-validation`, `allow-unsigned-executable-memory`, and all temporary exceptions.

Screen capture needs no entitlement. ScreenCaptureKit is controlled by TCC.

## Extensions: `Resources/Extension.entitlements` (unchanged)
`app-sandbox` plus `files.user-selected.read-only` for all four extensions: Annotate Share, Pin Share, Quick Look preview, and Quick Look thumbnail.

## Added when signing for real
`package-appstore.sh` merges `com.apple.application-identifier` and `com.apple.developer.team-identifier` from each provisioning profile into that bundle's entitlements.

## Direct edition (unchanged): `Resources/SuperScreenshot.entitlements`
`device.audio-input`, `device.camera`, `automation.apple-events`. It is not sandboxed and is signed with a local identity or ad-hoc. Moving it to Developer ID with notarization is a separate, credential-gated step.
