# Notes for App Review (draft)

Super Screenshot is a menu-bar app; it has no Dock icon. Click the viewfinder icon in the menu bar to open the menu.

1. On first launch, the welcome window asks for **Screen & System Audio Recording**. This is needed for every capture. Grant it, then quit and reopen the app when macOS asks.
2. Take an area screenshot with menu → Capture Area (default ⌘⇧4-style shortcut, see Settings → Shortcuts) and drag a rectangle. A Quick Access card appears; use **Save** (saves to ~/Pictures/Super Screenshot), **Annotate** (editor), **Pin**, or **Copy**.
3. To record: menu → Record Screen, select an area, then Record. The menu-bar icon becomes a stop button with a timer. Microphone and camera are off unless you turn them on in the recording toolbar, and each asks for permission the first time.
4. Capture Text (OCR) copies recognized text to the clipboard. Scrolling Capture stitches a scrolling area.
5. Optional permissions:
   - **Accessibility**: only for "Auto-Scroll" in scrolling capture (posting scroll events).
   - **Input Monitoring**: only to show typed keys during recordings.
   Everything else works without them.
6. The app has no account, collects no data, and downloads nothing. Uploads are disabled until the user configures their own S3-compatible or HTTP endpoint.
7. Settings → About → "Import Captures & Settings…" copies data from the separately distributed direct-download edition, if the user has it. It's optional.
