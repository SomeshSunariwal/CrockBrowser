# Crock Browser

One Flutter application in this repository root, with **Dart UI and Java Android services**. The supplied crocodile image is the launcher, splash, home and in-app brand. The app targets Android 13 or newer and uses Android WebView for websites.

## Open in Android Studio

Open **this existing project folder**, select the **main.dart** Run configuration and choose your Android device. Flutter and Dart plugins are installed on this machine. If asked for the Flutter SDK, select `tools/vendor/flutter` in this workspace. The Android SDK path is recorded locally in `android/local.properties`.

The Android view should have **one Gradle project: `android`**. Its `app` module builds Crock Browser. `lib/` and `android/` are two parts of the same application. There is no nested `mobile` project. After the migration, close and reopen this same folder and sync Gradle if Android Studio still displays its old duplicate Gradle entry.

## Source structure

```text
lib/
  main.dart                     Flutter application startup
  core/                         Models, encrypted-store interface, native bridge, theme
  features/
    browser/                    Browser chrome, navigation and page actions
    home/                       Search and editable/reorderable shortcuts
    tabs/                       Tab grid/list and session controls
    downloads/                  Download queue, forms and controls
    library/                    Local bookmarks, folders, history and offline pages
    files/                      File browser and local/device media library
    privacy/                    Private Space and saved passwords
    reading/                    Reader, translation, clipboard and contact autofill
    settings/                   Search engines and selected appearance controls
  shared/widgets/               Shared branded widgets and feature screens
android/app/src/main/java/com/example/crocbrowser/
  MainActivity.java             Thin Flutter activity
  browser/                      WebView and page scripts
  core/                         Platform routing, encrypted storage and device controls
  downloads/                    Persistent HTTP queue, adaptive media and torrents
  files/                        Scoped files, document picker and ZIP extraction
  media/                        Player, PiP, background audio and request context
  reading/                      On-device translation
  security/                     Device-lock-gated local secrets and private files
assets/branding/crock_logo.png    Original supplied artwork
```

The earlier Java/XML implementation is preserved under `analysis/legacy-java-reference/` as inspection material. It is excluded from the application, Dart analysis and the IDE source module. Decompiled UC code and APK binaries are never linked into this app.

## Build and checks

With Flutter on PATH:

```powershell
flutter pub get
flutter analyze --no-pub
flutter build apk --debug
```

This machine also has a helper for the local SDK and Windows Java temporary-directory workaround:

```powershell
.\tools\flutter-command.ps1 build apk --debug
```

Debug APK: `build/app/outputs/flutter-apk/app-debug.apk`. Android Studio can run the same root project. Release publication needs a production application ID and signing key. No automated test cases have been added or run, as requested.

## Features and limits

See [implementation status](docs/FEATURE_STATUS.md) for implemented behavior and manual validation, and [approved scope](docs/IMPLEMENTATION_SCOPE.md) for selected/excluded features. Download support includes direct HTTP files, supported HLS/DASH on-demand media and torrent links. Website authorization, DRM, server resume support, peer availability and Android background limits still apply. Adaptive media remains in Crock's offline player cache; torrent files are browsable in Files.

Local metadata and Private Space use Android Keystore encryption. Private browsing has a separate process/WebView profile and does not save tabs/history. Private file import makes an encrypted copy; the source file remains until explicitly deleted. Opening a private file in another application shares a temporary decrypted copy with that chosen app.

No UC advertising, analytics, accounts, cloud backup, VPN, AI or content-feed services were copied. Android WebView and optional ML Kit translation have their own platform/provider behavior; this is not a claim of anonymity or zero network telemetry.

Reference documents: [UC feature inventory](docs/UC_FEATURE_SELECTION.md), [APK/trackers/ownership audit](docs/APK_AUDIT.md), and [original Java UI reference](docs/UI_REFERENCE.html).
