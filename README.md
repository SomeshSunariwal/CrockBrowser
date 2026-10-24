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

## Build and Run Crock Browser

### 1. Set up the development environment

Install the following:

- **Flutter 3.47.7 with Dart 3.13.5**, the toolchain used for this project.
- **Android Studio**, with the Flutter and Dart plugins if you plan to work in the IDE.
- **Android SDK Platform 37** and **NDK 28.2.13676358**, as configured in the Android app module. Use Android Studio's bundled JDK.
- An Android 13+ device with USB debugging enabled, or a compatible Android emulator.

The project includes a Gradle wrapper; a separate Gradle installation is unnecessary.

Clone or download this repository, then open a terminal in its root directory—the folder containing `pubspec.yaml`.

```sh
flutter doctor
flutter doctor --android-licenses
flutter pub get
flutter analyze
```

Resolve any Android toolchain issues reported by `flutter doctor` before continuing. In Android Studio, open the repository root as a Flutter project and use `lib/main.dart` as the entry point.

### 2. Build and run on your device

Connect your device or start an emulator, then find its identifier:

```sh
flutter devices
```

Run the application, replacing `DEVICE_ID` with the listed identifier:

```sh
flutter run -d DEVICE_ID
```

To create an APK for development and local installation:

```sh
flutter build apk --debug
```

The APK is generated at `build/app/outputs/flutter-apk/app-debug.apk`.
