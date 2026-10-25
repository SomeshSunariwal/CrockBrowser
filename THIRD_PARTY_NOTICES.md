# Third-party components

## Bookmark logos

Google and YouTube bookmark logos are bundled for offline display. They were
obtained from the brands' official websites; the logos belong to their respective owners.

- Google: https://www.google.com/images/branding/googleg/1x/googleg_standard_color_128dp.png
- YouTube: https://www.youtube.com/s/desktop/dc0b62b0/img/favicon_144x144.png

## NewPipeExtractor

YouTube extraction uses NewPipeExtractor v0.26.5, licensed under
GPL-3.0-or-later by Team NewPipe and its contributors.

Source and license: https://github.com/TeamNewPipe/NewPipeExtractor/tree/v0.26.5

The license text is included in the APK at `licenses/NewPipeExtractor-GPL-3.0.txt`.
Distribution must comply with that license, including its corresponding-source requirements.

## Other runtime dependencies

The Android app also uses the following runtime dependencies.

- Flutter/Dart — BSD-style licenses: https://github.com/flutter/flutter and https://github.com/dart-lang/sdk
- AndroidX Core and Media3 — Apache 2.0: https://github.com/androidx/androidx and https://github.com/androidx/media
- ZXing Android Embedded / ZXing — Apache 2.0: https://github.com/journeyapps/zxing-android-embedded and https://github.com/zxing/zxing
- jlibtorrent 2.0.12.9 — wrapper and native dependencies have their own notices: https://github.com/frostwire/frostwire-jlibtorrent/tree/release/2.0.12.9 and https://www.libtorrent.org/
- OkHttp / Okio — Apache 2.0: https://github.com/square/okhttp and https://github.com/square/okio
- ML Kit on-device translation — Google SDK terms: https://developers.google.com/ml-kit/language/translation/android

Versions are pinned in `android/app/build.gradle.kts`; Dart dependencies are locked in `pubspec.lock`. Android's WebView is a system-provided component. APK dependency license/notice metadata remains with its libraries.

Archive extraction: Apache Commons Compress 1.28.0 (Apache 2.0, https://commons.apache.org/proper/commons-compress/), XZ for Java 1.10 (0BSD, https://tukaani.org/xz/java.html), Junrar 8.1.2 (UnRAR license, https://github.com/junrar/junrar/tree/v8.1.2). The app reads archives; it does not create RAR files. Junrar's license prohibits using it to develop a RAR-compatible archiver. The dependency's own license notices must accompany distribution.
