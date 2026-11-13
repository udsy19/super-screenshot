# Privacy

**Super Screenshot is a local app. Nothing leaves your Mac unless you upload it yourself.**

## What Super Screenshot does not do

- **No accounts.** There is nothing to sign up for.
- **No analytics or telemetry.** Super Screenshot never tracks usage or sends crash reports. Its only request of
  its own is the update check described below.
- **No servers.** The project doesn't operate any; there is nowhere for your data to go.

## What stays on your Mac

| Data | Location |
|---|---|
| Screenshots and recordings you haven't saved | `~/Library/Application Support/SuperScreenshot/Media` and `…/Recordings` |
| Studio projects and Annotate documents | `~/Library/Application Support/SuperScreenshot/Projects` (or wherever you save them) |
| Capture History index | `~/Library/Application Support/SuperScreenshot/History` — retention is configurable, or turn History off |
| Settings | `~/Library/Preferences/com.udsy.superscreenshot.plist` |
| Upload credentials (S3 secret key) | macOS Keychain |
| Update downloads (while being verified) | `~/Library/Application Support/SuperScreenshot/Updates` — deleted afterwards |

Text recognition, scrolling-capture stitching, video encoding and everything else runs on-device using Apple's
frameworks (Vision, ScreenCaptureKit, AVFoundation).

## Uploads (opt-in)

Uploading is off until you configure a destination in **Settings → Upload**. When you upload, the file goes
directly from your Mac to the destination **you** chose — your own S3-compatible bucket, your own HTTP endpoint,
or a folder on your disk. Super Screenshot is not involved beyond sending the request.

## Automatic updates

With **Settings → General → Install updates automatically** on (the default), Super Screenshot asks GitHub whether a
newer release exists: a minute after launch, then every 6 hours while it runs, and never more than once in 4 hours.
That is one anonymous HTTPS request to `api.github.com/repos/udsy19/super-screenshot/releases/latest` — no account,
identifiers, cookies or usage data. Like any web request it reaches GitHub from your IP address, and it names the
app version in its User-Agent (`SuperScreenshot/1.3.0`).

When a newer version exists, its disk image is downloaded from GitHub Releases, checked against the SHA-256 in the
release notes and against the code signature of the copy you already have, and installed when you quit — or, after
10 minutes without keyboard or mouse input and with no Super Screenshot windows open, swapped in and relaunched in
the background. If the app's folder isn't writable for your account, nothing is downloaded. Turn the setting off and
Super Screenshot makes no network requests other than the uploads you configure.

## Permissions

| Permission | Why |
|---|---|
| Screen & System Audio Recording | Taking screenshots and recordings |
| Accessibility (optional) | Showing keystrokes in recordings, auto-scroll during scrolling capture |
| Microphone / Camera (optional) | Only when you turn them on for a recording |

## Removing everything

Run `curl -fsSL https://udsy19.github.io/super-screenshot/install.sh | bash -s -- --uninstall`, then delete
`~/Library/Application Support/SuperScreenshot` and `~/Library/Preferences/com.udsy.superscreenshot.plist`.

## Mac App Store edition

Super Screenshot from the Mac App Store (`com.udsy.superscreenshot.appstore`) follows everything above, with these differences:

- **Data collected by the developer: none.** No analytics, no accounts, no servers.
- **No updates check.** The App Store edition has no built-in updater and never contacts GitHub; the App Store updates it. Its only network use is uploads you set up yourself to your own S3-compatible bucket or HTTP endpoint (off until configured).
- **Permissions:** Screen & System Audio Recording for every capture and recording; Microphone and Camera only when you turn them on for a recording; Accessibility (post events) only for auto-scroll in scrolling capture; Input Monitoring only for the keystroke overlay. Each is requested when you first use the feature.
- **Recording:** starts only from an action you take, and while it runs a stop button is always shown in the menu bar, in addition to macOS's own recording indicators.
- **Where data lives:** unsaved captures, history, recordings and projects in the app's sandbox container, `~/Library/Containers/com.udsy.superscreenshot.appstore/`; saved files in `~/Pictures/Super Screenshot` or a folder you choose.
- **Removing everything:** delete the app, then the container folder above.
