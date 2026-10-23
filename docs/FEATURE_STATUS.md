# Crock Browser implementation status

Updated 23 October 2026. The single active application is in the workspace root. Flutter UI lives in `lib/`; Java services live in `android/app/src/main/java/`. Android Studio links only the `android` Gradle project. The original application ID is retained so updates preserve local data. The user-facing name is **Crock Browser** throughout the current app.

## Implemented source

| Area | Current behavior |
|---|---|
| UI and logo | Branded home, browser chrome, menu/tools, download screens, tabs, bookmarks/history/offline library, files/media, Private Space/passwords, contact autofill, reader/translation, clipboard and settings. Supplied logo on launcher, splash, home, about/empty states, player and notification artwork. Branded navigation-error screen. |
| Basic browser | Android WebView, HTTP/HTTPS address/search navigation, back/forward/reload/home, page progress/errors, long-press link actions, sharing, file uploads and camera/microphone permission prompts. Android WebView's built-in Safe Browsing remains enabled. |
| Downloads — HTTP | Persistent encrypted queue metadata/request context, bounded concurrency, bytes/speed/progress, background notification, pause/resume with Range/object validation, retry/cancel/remove, server redirect checks, unmetered-network option, destination picker, local files and export/share. Interrupted active/retrying rows return to the queue when the service restarts. |
| Downloads — media | Detect direct page media and request context. Media3 handles supported on-demand HLS/DASH playlists with resumable segment caching and offline playback in Crock Player. |
| Downloads — torrent | Magnet links and HTTP `.torrent` metadata via jlibtorrent; progress, pause/retry, recheck/resume existing pieces and local torrent folders. Completed transfers stop instead of continuing to seed. Open navigates into the downloaded folder. |
| Tabs/privacy | New/select/close/close-all, grid/list, reopen closed normal tabs, normal URL/session restoration, per-site desktop/mobile preference. Private activity has a separate process and WebView profile, suppresses screenshots, and never saves private tabs/history. Its profile is discarded for the next private process. |
| Bookmarks/history | Local folders/subfolders, add/edit/move/delete, Netscape HTML/JSON import, HTML export, searchable history and clearing. No cloud sync or backup subsystem. |
| Home/search | Add/edit/delete/reorder shortcuts, engine selection, custom query templates and multi-engine searches in tabs. |
| Appearance | Font/text zoom, app-window brightness and rotation controls. |
| Files/media | Managed file browsing/search/filter, import/export/share/rename/delete, ZIP extraction with traversal/size guards, device media queries after permission, image preview, native Media3 playback, speed, PiP and explicit background audio. |
| Private Space | Device-screen-lock gate, Keystore-encrypted metadata/passwords/contact profile and private-file copies, five-minute access window, explicit locking and temporary previews. |
| Reading/input | Saved MHT pages, extracted-text reader, text export, on-device ML Kit translation after explicit model download, saved-login fill with origin checks, explicit contact-form fill, OS keyboard assistance, explicitly saved clipboard entries, QR/barcode scanning. |
| Blocking | Optional small built-in ad-host block list and manual element hiding per host. Rules can be cleared. This is a basic blocker rather than a full filter-list engine. |

## Validation

No automated test cases were added or run. Flutter formatting/static analysis, Android debug builds and Android lint pass. Manual emulator inspection has covered branded startup/home, browser navigation to a synthetic local page, menu/download entry, the new-download form, Android notification permission flow, a completed 16 MB HTTP transfer in the background, and a second transfer paused at 9.6 MB, resumed using HTTP 206, then completed at 16 MB. The form lifecycle and small-screen shortcut layout were corrected after manual checks. Further manual results are recorded below as they are completed; a successful build alone does not validate every advanced backend.

## Practical limits and remaining validation

- Website-specific social-download extraction, DRM decryption, live-stream recording and bypassing site restrictions are not implemented. Supported downloadable URLs depend on what the page exposes and the permissions of the current session.
- Adaptive downloads are segment caches for the in-app player, not a single MP4 export. Torrent folders support individual-file browsing/export; selective torrent-file priorities and peer controls are not implemented.
- HTTP resume depends on server behavior and validators. Android may limit long-running foreground transfers; the service pauses on its timeout callback so transfers can be resumed.
- Archives currently mean ZIP. RAR/7z extraction is not implemented.
- Reader extraction is based on article/main/body text and can be imperfect on complex websites. Translation depends on the optional model download. Autofill is explicit within this browser, not an Android-wide AutofillService.
- Private Space imports an encrypted copy; it does not silently delete the original. Opening with another app grants that chosen app a temporary decrypted preview. The app's unlock gate is enforced in code; this is not a separate hardware-authentication-bound vault key.
- Normal cold-start restoration restores tab URLs/titles/preferences, not native WebView back/forward history or page process state. Private tabs are never restored.
- End-to-end checks of torrent peers, HLS/DASH offline playback, device-lock flows, translation models, QR camera scanning and long-running background/OS quota behavior remain device-dependent manual verification work.

Accounts, cloud backup/sync/drive, VPN, AI, news/story/game feeds, promotions, advertising and usage analytics were excluded. Decompiled UC code/resources/native engines are not packaged in the app. WebView and optional translation SDK behavior is governed by their providers; the app does not claim anonymity or zero provider telemetry.
