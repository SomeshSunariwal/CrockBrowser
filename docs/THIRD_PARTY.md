# Runtime dependencies

The Android app uses newly written source plus these dependencies. Decompiled UC Browser code and its SDKs are not linked into the app.

- Flutter/Dart — BSD-style licenses: https://github.com/flutter/flutter and https://github.com/dart-lang/sdk
- AndroidX Core and Media3 — Apache 2.0: https://github.com/androidx/androidx and https://github.com/androidx/media
- ZXing Android Embedded / ZXing — Apache 2.0: https://github.com/journeyapps/zxing-android-embedded and https://github.com/zxing/zxing
- jlibtorrent 2.0.12.9 — wrapper and native dependencies have their own notices: https://github.com/frostwire/frostwire-jlibtorrent/tree/release/2.0.12.9 and https://www.libtorrent.org/
- OkHttp / Okio — Apache 2.0: https://github.com/square/okhttp and https://github.com/square/okio
- ML Kit on-device translation — Google SDK terms: https://developers.google.com/ml-kit/language/translation/android

Versions are pinned in `android/app/build.gradle.kts`; Dart dependencies are locked in `pubspec.lock`. Android's WebView is a system-provided component. APK dependency license/notice metadata remains with its libraries.

Archive extraction: Apache Commons Compress 1.28.0 (Apache 2.0, https://commons.apache.org/proper/commons-compress/), XZ for Java 1.10 (0BSD, https://tukaani.org/xz/java.html), Junrar 8.1.2 (UnRAR license, https://github.com/junrar/junrar/tree/v8.1.2). The app reads archives; it does not create RAR files. Junrar's license prohibits using it to develop a RAR-compatible archiver. The dependency's own license notices must accompany distribution.
