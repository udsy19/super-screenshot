# Compliance matrix

| Feature | Classification | Store status | Evidence |
|---|---|---|---|
| Area / window / fullscreen / previous-area / self-timer capture | compatible-with-config | Implemented on ScreenCaptureKit; needs Screen Recording TCC | TCC request fired in the sandboxed run; the granted path needs a human |
| OCR (Vision) | compatible-with-config | as capture | needs a human |
| Scrolling capture | compatible-with-config | Manual scrolling as capture; auto-scroll posts CGEvents and is gated on `CGPreflightPostEventAccess` | unverified-needs-experiment for posting from the sandbox |
| Annotate editor, Save, Save As, projects | compatible | Works | Saved to `~/Pictures/Super Screenshot` sandboxed, with no denial |
| Screen recording (video / GIF) | compatible-with-config | needs TCC; visible indicator (menu-bar stop button and timer) | needs a human |
| Microphone and system audio in recordings | compatible-with-config | opt-in; both mic keys and usage strings present | needs a human |
| Camera overlay | compatible-with-config | opt-in | needs a human |
| Studio Mode (cursor, click and scroll tracking) | compatible-after-architecture-change | global monitors replaced by a listen-only CGEventTap in the Store build | compiles; needs a human |
| Keystroke overlay, global Esc | compatible-after-architecture-change | event tap plus Input Monitoring | needs a human |
| Quick Access overlay | compatible | Works | exercised |
| Pins | compatible | Works | exercised (named-pasteboard pin) |
| Capture History | compatible | Works | window shown; imported history merged |
| Hide desktop icons | compatible | Works (wallpaper from ScreenCaptureKit, otherwise falls back) | exercised |
| Color picker (NSColorSampler) | compatible | Unchanged | not exercised |
| Global shortcuts (Carbon `RegisterEventHotKey`) | compatible | Unchanged | not exercised (synthetic input forbidden) |
| Export and upload folders | compatible-after-architecture-change | default Pictures; chosen folders kept with security-scoped bookmarks | default exercised; bookmark persistence across relaunch needs a human picker run |
| Uploads (S3, custom HTTP, folder) | compatible-with-config | `network.client`; the folder destination uses a bookmark | not exercised |
| Share extensions (Annotate, Pin) | compatible-after-architecture-change | handoff via named pasteboard to the containing app | app side exercised; extension side needs a human (Share menu) |
| Quick Look preview and thumbnail extensions | compatible | already sandboxed; re-identified under the Store id | not exercised in the Store bundle (would conflict with the installed direct edition's registration) |
| URL scheme API | compatible-with-config | `filepath=` only works for locations the app can reach | denial plus panel fallback observed |
| Launch at login (SMAppService) | compatible | Unchanged | not exercised |
| Import from direct edition | compatible | Settings → About | library import exercised sandboxed (originals unchanged); settings via self-test fixture |
| Self-updater (UpdateKit) | incompatible-confirmed | Compiled out of the Store build | `nm` / `strings` show nothing |
| Apple Events entitlement | incompatible-confirmed (policy) | Removed; it was never needed for sending | entitlements dump |
| Content-sharing picker (SCContentSharingPicker) | — | Not adopted; the app keeps its own area and window selection | review risk (see known-blockers.md) |
