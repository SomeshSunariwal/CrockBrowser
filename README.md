# Crock Browser

**Your browser. Your build. Your control.**

## Overview

Crock Browser is a local-first Android browser built with Flutter and native Android services. It combines Android WebView with a customizable interface, tab management, downloads, and tools for everyday browsing.

The application runs on **Android 13 and newer**. Its interface is written in Dart, with Java handling WebView integration, downloads, device storage, and media playback.

Features include:

- **Flexible browsing:** grid and list tab views, page previews, configurable search engines, and static or dynamic address-bar behavior.
- **Download management:** progress graphs, pause and retry controls, and Android notifications.
- **Local organization:** bookmarks, browsing history, shortcuts, offline pages, and a file browser.
- **Reading and media tools:** reader mode, translation, media playback, and archive extraction.
- **Personalization:** light and dark themes, display preferences, and editable home shortcuts.

## Why Use Crock Browser?

### No built-in advertising or analytics trackers

Crock Browser does not include advertising networks or behavioral analytics SDKs. No browser account or browser-operated cloud service is required to use it.

This describes the browser application's own integrations. Websites can still use cookies and trackers; Android WebView and optional translation components also have their own provider behavior.

### Your data stays under your control

Bookmarks, browsing history, preferences, and download records are stored on your device. Sensitive application data uses Android Keystore-backed encryption. Private browsing uses a separate WebView profile and does not save browsing history or tabs.

### Browsing that fits your preferences

Choose your search engine, theme, display settings, and home shortcuts to tailor Crock Browser to your workflow.

## Build and Run in Android Studio

### 1. Download the development tools

Install **Git** and [Android Studio](https://developer.android.com/studio), then complete Android Studio's first-run setup.

Download the Flutter SDK separately—the Android Studio Flutter plugin does not include it:

1. Open the official [Flutter SDK archive](https://docs.flutter.dev/install/archive).
2. Select your operating system and CPU architecture, then download **Flutter 3.47.7 (stable)**. This project uses its bundled **Dart 3.13.5** SDK; Dart does not need a separate installation.
3. Extract the archive outside this repository, for example to `C:\development\flutter` on Windows. The SDK folder should contain `bin`, `packages`, and `README.md`.
4. Choose a writable location without spaces or administrator-only permissions. Avoid `Program Files` and keep the SDK when cleaning project build files.

For other operating systems, follow the official [manual installation guide](https://docs.flutter.dev/install/manual).

### 2. Add Flutter to PATH

On Windows:

1. Search the Start menu for **Edit environment variables for your account**.
2. Under **User variables**, select **Path**, click **Edit**, then **New**.
3. Add the SDK's `bin` directory, such as `C:\development\flutter\bin`, and save.
4. Close and reopen your terminals and Android Studio so they pick up the change.

In a new terminal, verify:

```sh
flutter --version
dart --version
```

For macOS or Linux, use the official [PATH instructions](https://docs.flutter.dev/install/add-to-path).

### 3. Configure Android Studio and Android SDK

In Android Studio:

1. Open **Settings > Plugins > Marketplace**, install **Flutter**, accept the Dart plugin dependency, and restart the IDE if prompted. On macOS, open Settings from the Android Studio application menu.
2. Open **Tools > SDK Manager**, or **More Actions > SDK Manager** from the welcome screen.
3. Under **SDK Platforms**, install **Android SDK Platform 37**.
4. Under **SDK Tools**, install **Android SDK Build-Tools**, **Android SDK Platform-Tools**, **Android SDK Command-line Tools (latest)**, and **NDK (Side by side) 28.2.13676358**. Use **Show Package Details** to select the NDK version. Install **Android Emulator** if you plan to use a virtual device.
5. Use Android Studio's bundled JDK for Gradle. The project includes the Gradle wrapper; do not install Gradle separately.

Accept the Android licenses, then check the toolchain:

```sh
flutter doctor --android-licenses
flutter doctor -v
```

Resolve issues reported for Flutter, Android toolchain, or Android Studio before continuing. See Flutter's [Android setup guide](https://docs.flutter.dev/platform-integration/android/setup).

### 4. Prepare the downloaded project

Clone this repository or download and extract its ZIP. Open a terminal in the **project root**, the folder containing `pubspec.yaml`, `lib`, and `android`.

Run:

```sh
flutter pub get
flutter build apk --debug
```

This restores dependencies and performs the initial build. Flutter generates `android/local.properties` with your machine's `flutter.sdk` and `sdk.dir` paths, and Android generates its resource classes, including `R`.

**Do not create `local.properties` manually or copy it from another computer.** It is intentionally ignored by Git. Prepare the project through Flutter before attempting a standalone Gradle build of the `android` folder.

On macOS or Linux, run `chmod +x android/gradlew` first if the wrapper is not executable after downloading the source.

### 5. Open the project in Android Studio

1. Select **Open** and choose the **project root containing `pubspec.yaml`**. Use the existing project; do not create a new project or import only its `android` subfolder.
2. In **Settings > Languages & Frameworks > Flutter**, set **Flutter SDK path** to the extracted SDK's root, such as `C:\development\flutter`. Select the folder containing `bin`, not `bin` itself.
3. Allow dependency loading, indexing, and Gradle sync to finish.
4. Open `lib/main.dart`. Select the Flutter run configuration for this file. If it is missing, use **Run > Edit Configurations > + > Flutter** and set the Dart entry point to `lib/main.dart`.

See the official [Android Studio Flutter guide](https://docs.flutter.dev/tools/android-studio) for IDE setup and run controls.

### 6. Start a device and run

Use **Tools > Device Manager** to create and start an emulator running **Android 13 / API 33 or newer**, or connect a physical Android 13+ device with USB debugging enabled and accept its debugging authorization prompt.

Select the device in Android Studio's target dropdown, then click **Run** for `lib/main.dart`.

Alternatively, from the project root:

```sh
flutter devices
flutter run -d DEVICE_ID
```

Replace `DEVICE_ID` with the identifier reported by `flutter devices`.

The debug APK is written to `build/app/outputs/flutter-apk/app-debug.apk`. For a release APK, run `flutter build apk --release`; its output is `build/app/outputs/flutter-apk/app-release.apk`. The current release configuration uses development signing—configure your own signing key before publishing.

The Android application ID is `com.browser.crockbrowser`.

### Setup troubleshooting

| Problem                                                          | What to check                                                                                                                                 |
| ---------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `flutter` is not recognized                                      | Add the SDK's `bin` directory to your user `PATH`, then reopen the terminal and IDE.                                                          |
| `flutter.sdk not set in local.properties` or the file is missing | Check the Flutter SDK setting, then run `flutter pub get` and `flutter build apk --debug` from the project root. Retry Gradle sync afterward. |

Keep SDK paths, IDE settings, signing keys, and generated build output local. Commit application sources, assets, dependency manifests and lockfiles, and the Gradle wrapper.

Dependency notices are listed in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
