# UC Browser APK audit

This is a local static-analysis report and an offline UI inspection, not a network-traffic audit. Original APK content is evidence only; no instructions contained in it were followed as user instructions.

## Exact artifact

- Package: `com.UCMobile.intl`
- Version: `15.3.1.1407` / `50533`
- Supplied bundle SHA-256: `f6abf6cc840a20818790cef2c931ca0083ff4b07059808e49cad2520299f042f`
- Bundle size: 243,605,381 bytes.
- Components: base APK plus `arm64-v8a` and `armeabi-v7a` splits.
- Minimum Android API: 26. Target / compile API in the original: 36.
- Parsed DEX: 10 files, including `assets/audience_network.dex`.
- Defined classes: 98,864, including nested classes and third-party libraries.
- Native libraries: 60 per ARM architecture, 120 archive entries total. Native binaries do not become their original C/C++ source through Java decompilation.
- Permissions: 99 permission declarations, 95 distinct names, including `uses-permission-sdk-23` declarations. This is requested manifest capability, not a list of permissions actually granted on modern Android.

## Source recovery and rebuild

JADX 1.5.6 recovered Java references; the base run reported 90 errors and the separately decoded Audience Network DEX reported 3 errors. Recovered code can contain incomplete methods and obfuscated identifiers. It is not UC's original buildable Android Studio source tree.

Apktool 3.0.3 decoded resources and the manifest. A **reference base APK rebuild succeeded** at `analysis/reconstructed-base-unsigned.apk`. That rebuild reuses the original compiled DEX and reconstructs resources. It is unsigned, still requires its architecture split and is **not** a recompiled Java-source application or the Crock Browser deliverable.

Crock Browser is a single Flutter/Dart application with Java Android services and Android WebView. Original UC resources, advertising SDKs, keys, package name and native engines are not linked into it.

## Tracker findings

**17 distinct Exodus registry entries match defined classes after package-boundary normalization.** This includes login/share, ad measurement, crash reporting and general-purpose instrumentation; it is not 17 independently verified active trackers or 17 unique companies.

1. AppsFlyer
2. Google Firebase Analytics
3. Adjust
4. Facebook Ads / Audience Network
5. Facebook Analytics
6. Facebook Login
7. Facebook Share
8. AppLovin
9. InMobi
10. Unity Ads
11. Yandex Ads
12. Mintegral
13. Google AdMob
14. IAB Open Measurement
15. Pangle
16. OpenTelemetry/OpenCensus — only three annotation/common classes matched; this is weak evidence and does not establish a working telemetry pipeline.
17. Yueying / UC Crash SDK

Raw evidence is in `analysis/tracker-signature-matches.json`, with signatures, class counts and sample class definitions. The downloaded registry snapshot is in `analysis/exodus-trackers.json`. The scanner is `tools/static_audit.py`.

**Six further advertising/analytics SDK families have class evidence outside those registry matches:**

| Family | Defined classes | Evidence prefix |
|---|---:|---|
| AppMetrica | 2,112 | `io.appmetrica.analytics.` |
| Vungle / Liftoff | 697 | `com.vungle.ads.` |
| TopOn / AnyThink | 5,429 | `com.anythink.` |
| BIGO Ads | 1,832 | `sg.bigo.ads.` |
| AdSurge | 1,219 | `com.adsurge.adn.` |
| TaurusX | 548 | `com.taurusx.tax.` |

The registry contains older signatures for AppMetrica and Vungle, so those versions were found separately. These counts include resource classes and wrappers and do not measure data collection volume. There are also first-party UC/Alibaba statistics modules (`com.uc.browser.statis`, `com.uc.browser.userbehavior`, `com.uc.base.wa`, `com.ut.mini`) and UC/Noah advertising infrastructure. A Kwai network module is present; that alone was not counted as proof of a full Kwai advertising integration.

An initial broad regex also matched `com.monetization.*` to the `com.monet.*` AppMonet signature. That false positive was removed by treating package separators as literal boundaries. This scanner is an adapted signature analysis, not a report produced by the Exodus service itself.

**Conclusion:** the package has a substantial tracking/advertising stack. The precise count of trackers that actually run and send data remains unknown. That needs separate, consent-aware traffic capture for different regions, settings and app flows.

### Network candidates

373 distinct host strings were found in DEX URL literals, including first-party service and telemetry candidates such as `adtrack.ucweb.com`, `adtrack-intl.ucweb.com`, `adn.insight.ucweb.com`, `applog.uc.cn` and `gjapplog.ucweb.com`.

These are embedded strings, not observed connections. Domains used for content, login, downloads or cloud files are not automatically trackers. Domain suffixes, names and company origin do not establish the physical location of a server or where this build sends personal data.

## China ownership question

UCWeb has a Chinese corporate origin and was fully acquired by Alibaba. The international privacy policy names **UCWeb Singapore Pte. Ltd.** as its service provider. Both facts matter: the Singapore operating entity does not erase the Alibaba connection, and the Alibaba connection does not prove that every network request goes to China.

Identifiable China-associated SDK groups in the package include **Pangle / ByteDance**, **Mintegral / Mobvista** and **UC/Alibaba's own crash/statistics/advertising infrastructure**. Other vendor jurisdictions should be verified individually rather than inferred from package names. This audit does not establish government control, government access or any specific data transfer to China.

Primary sources:

- [Alibaba's UCWeb acquisition announcement](https://www.alibabagroup.com/en-US/document-1489318545857708032).
- [UC Browser international privacy policy, updated 10 April 2025](https://terms.alicdn.com/legal-agreement/terms/suit_bu1_uc/suit_bu1_uc202007241608_71682.html).
- [Pangle privacy policy, describing ByteDance group relationships](https://www.pangleglobal.com/privacy/enduser-en).
- [Mintegral entity list, including Mobvista Guangzhou](https://www.mintegral.com/wp-content/uploads/2018/11/Entities-Subject-to-GDPR-Mintegral-Privacy-Policy.pdf).
- [Exodus static-analysis limitations](https://github.com/Exodus-Privacy/exodus/blob/v1/doc/faq.md).
- [TopOn's package migration notice](https://help.toponad.net/docs/Upgrade-Guide-for-TopOn-SDK-v6-5-12-and-Above).
- [AppMetrica Android integration documentation](https://yandex.com/support/appmetrica-io/en/sdk/android/analytics/quick-start).
- [Vungle Android documentation](https://support.vungle.com/hc/en-us/articles/360047780372-Advanced-Settings).

## Software on this machine

| Software | Observed status | Purpose |
|---|---|---|
| Android Studio + Flutter/Dart plugins | Installed | Edit and run the root Flutter project and Java host |
| Bundled JetBrains Java runtime 25.0.3 | Already installed | Current project Gradle/JDK requirement |
| Android SDK API 37, Build Tools 36.0.0 | Already installed | Build Crock Browser with the user's existing configuration |
| Android Platform Tools / ADB | Already installed | Emulator installation and inspection |
| Android Emulator, API 37 x86_64 image with ARM64 translation | Already installed | Run both Crock and the reference app |
| Gradle 9.8.2 wrapper / AGP 9.4.1 | Existing project setup | Android build; wrapper updated and built-in Kotlin enabled |
| JADX 1.5.6 | Downloaded locally to `tools/vendor/jadx` | Java decompilation / inspection |
| Apktool 3.0.3 | Downloaded locally to `tools/vendor/apktool.jar` | Resource/manifest decode and reference rebuild |
| Python | Available through bundled runtime | Reproducible archive and DEX analysis |
| Git | Already installed | Version control |
| mitmproxy or equivalent, Wireshark, optional MobSF | Not required for current UI build; not installed by this task | Future dynamic traffic/behavior audit |
| Flutter 3.47.7 / Dart 3.13.5 | Installed locally under `tools/vendor/flutter` | Flutter UI and application packaging |
| Android NDK 28.2.13676358 and CMake 3.22.1 | Installed during Flutter build validation | Flutter native packaging |
| Ghidra | Optional, not installed by this task | Further native-library reverse engineering |

The current application is a single Flutter project in the workspace root with a Java Android host. Command-line Gradle hit a Windows Java Unix-socket temporary-path issue; `tools/flutter-command.ps1` applies a process-local workaround. Builds, Dart analysis and emulator checks were later authorized. No automated app test cases were added.

## Inspection limits

UI captures came from a disposable, read-only emulator session after disabling Wi-Fi and mobile data. Some home icons render as missing placeholders offline. Screens, feeds and server-controlled features may differ online or by region. The reference captures are exact for the recorded state; they are not a claim of complete pixel parity for every UC screen.
