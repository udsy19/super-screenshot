# Dependency and license audit

| Component | Version | License | Kind | Bundled | Sandbox OK |
|---|---|---|---|---|---|
| Super Screenshot source | 1.3.2 | MIT (`LICENSE`) | first-party | yes | yes |
| Apple frameworks (AppKit, SwiftUI, ScreenCaptureKit, AVFoundation, Vision, CryptoKit, ServiceManagement, Quick Look) | macOS SDK 26.5 | Apple SDK | system | no (OS) | yes |

- `Package.swift` declares **no package dependencies**.
- Nothing is vendored, no binary frameworks, no GPL code, no ffmpeg.
- System sounds are loaded from `/System/Library/...` at runtime and are not bundled; the sandbox allows reading them.
- The About pane states the app is an independent reimplementation of the CleanShot X feature set and isn't affiliated with it. See the review risk in known-blockers.md.

**Export compliance.** The app uses HTTPS (URLSession), and CryptoKit HMAC-SHA256 and SHA-256 for AWS SigV4 request signing. That is authentication only, with no proprietary or non-exempt encryption. The SHA-256 DMG verification in UpdateKit is compiled out of the Store build. On that basis the build sets `ITSAppUsesNonExemptEncryption=false`; the owner should confirm this.
