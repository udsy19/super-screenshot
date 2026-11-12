# Privacy and permissions

All capture, OCR (Vision) and editing happen on the device. There is no analytics, no account and no tracking. The network is used only for uploads the user sets up to their own S3 or HTTP endpoint. The S3 secret is kept in the Keychain.

| Permission | Used for | How it's requested | Without it |
|---|---|---|---|
| Screen & System Audio Recording (TCC) | every screenshot, recording, OCR, scrolling capture | `CGRequestScreenCaptureAccess` at onboarding or first capture | alert with "Open System Settings"; nothing is written |
| Microphone | narration in recordings (off by default, enabled per recording) | `AVCaptureDevice.requestAccess(.audio)`; `NSMicrophoneUsageDescription` | recording continues without the mic |
| System audio | recording system sound (opt-in) | ScreenCaptureKit; `NSAudioCaptureUsageDescription` | — |
| Camera | camera overlay during recordings (opt-in) | `NSCameraUsageDescription` | overlay unavailable |
| Accessibility (post events) | auto-scroll in scrolling capture | `CGRequestPostEventAccess` | manual scrolling still works; a hint explains |
| Input Monitoring (Store edition) | keystroke overlay; Esc while another app is frontmost | `CGRequestListenEventAccess` | no keystroke overlay; Esc works in our own windows and the menu-bar stop button always works |

**Recording consent and indicator (guideline 2.5.14).**
- Recording starts only from an explicit user action: a menu command, a shortcut, or the Record button in the setup overlay.
- The microphone and camera are separate opt-in toggles.
- While recording, the menu-bar icon becomes a stop button showing the elapsed time, and the recording frame and controls stay on screen.
- macOS also shows its own screen-recording and microphone indicators.

**TCC grants don't transfer** from the direct edition to the Store edition (different bundle id and signature). Users must grant permissions again.

**Data locations (Store edition).**
- `~/Library/Containers/com.udsy.superscreenshot.appstore/Data/Library/Application Support/SuperScreenshot`: unsaved captures, history, recordings, projects and recovery copies.
- Saved files go to `~/Pictures/Super Screenshot` or to folders the user chooses.

The privacy nutrition label should be **Data Not Collected**. Uploads go to destinations the user owns, and the developer receives nothing.
