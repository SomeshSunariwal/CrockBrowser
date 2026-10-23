# Crock Browser approved implementation scope

Approved 23 October 2026. The application will use **Flutter UI with Java Android services**. No automated test cases are to be added. The user subsequently authorized **builds, emulator use and manual validation** so the integration can be checked properly. Source inspection, formatting and static analysis are also allowed.

## Priorities

1. **UI completion**: complete native-feeling screens with the supplied crocodile logo, clear navigation and all selected feature entry points. No default Android robot or Flutter branding.
2. **Downloads**: foreground/background file transfers, progress/speed/status, queue/concurrency, pause/resume when supported by the server, retry/cancel, destination selection, downloaded-file actions and supported direct media links. Torrent support is a distinct download backend, not an HTTP download.
3. **Tabs/privacy**: tab creation/switching/closing, alternate views, cold-start restoration for normal tabs, isolated private browsing with no persisted history/session.
4. **Local bookmarks**: folders, editing, import/export, history and clearing. No backup or cloud synchronization.
5. **Home/search**: editable/reorderable shortcuts, search engine selection/custom engines/meta-search and desktop/mobile site preferences.
6. **Appearance controls**: font size, brightness and rotation. New themes, wallpaper systems and localization are outside the selected scope.
7. **Media/files**: media library and player, speed/background/floating playback, file management, archives and protected Private Space.
8. **Reading/input**: offline pages/reader, translation, local autofill/password storage, typing assistance, clipboard manager and QR/barcode scanning.
9. **Lowest priority**: ad blocking and manual element/ad removal.

Cloud services, accounts, VPN, AI chat/notes, content feeds, games, advertising and analytics were not selected. System notifications/background services required to implement selected downloads and playback are included as supporting infrastructure.

## Architecture

The workspace root is the single Flutter application, with feature folders under `lib/features/` and a Java host under `android/app/src/main/java/`. Dart platform interfaces isolate UI from native services. The earlier Java/XML source is preserved under `analysis/legacy-java-reference/`; `analysis/` is inspection material and is never linked into the app. There is no nested `mobile` application.

The native layer will own downloads, storage permissions/document access, secure local storage, device controls and media integration. Flutter owns the branded screen system and feature presentation. Browser rendering uses Android WebView through a native-view integration.

## Logo

The supplied original image is the single branding source. Use it on the launcher, Android splash, Flutter startup/home/about/empty states and notification artwork as appropriate. All generated default launcher icons must be replaced. Image layout sizes and Android launcher-density assets must match their target context without distorting the aspect ratio.

## Implementation truthfulness

A screen being present does not mean its backend is complete. Track actual implementation state in the repository. Downloads from sites requiring authorization must carry the relevant request context. Resume depends on server support and object validators; a normal HTTP downloader cannot promise universal social/video or torrent downloads. Private browsing and local secret storage must not claim protections their implementation does not provide.
