# UC Browser feature selection

Reference: supplied `com.UCMobile.intl` **15.3.1.1407**, version code **50533**. Audited 23 October 2026.

Selection was completed: see [approved implementation scope](IMPLEMENTATION_SCOPE.md) and [current feature status](FEATURE_STATUS.md). This table preserves the original UC inventory. This is a feature inventory, not a claim that every remote UC service works offline or will be copied into Crock Browser.

Evidence labels: **Screen** = visible in the supplied app on the offline emulator. **Package** = found in its classes, layouts, strings or bundled assets; availability may depend on region, account or server configuration.

| No. | Feature | Evidence | Selection |
|---|---|---|---|
| 1 | Open websites and search from a combined address/search bar | Screen | Core |
| 2 | Back, forward, refresh and home navigation | Screen | Core |
| 3 | Multiple tabs, tab switching and closing tabs | Screen / Package | Core |
| 4 | Reopen previous tabs on startup and alternate tab views | Screen | Pending |
| 5 | Incognito browsing | Package | Pending |
| 6 | Bookmarks and bookmark folders | Screen / Package | Pending |
| 7 | Bookmark import, export and backup | Package | Pending |
| 8 | Browsing history and clear-history controls | Screen / Package | Pending |
| 9 | Home shortcuts and adding/editing favorite sites | Screen / Package | Pending |
| 10 | Search-engine selection and meta search | Screen | Pending |
| 11 | Desktop/mobile website preferences and user agents | Screen | Pending |
| 12 | Night mode | Screen | UI preview |
| 13 | Themes, wallpapers and custom backgrounds | Screen / Package | Pending |
| 14 | Language selection and localization | Screen / Package | Pending |
| 15 | Font size, zoom, brightness, rotation and status-bar preferences | Screen / Package | Pending |
| 16 | Ad blocker and manual ad removal/reporting | Screen / Package | Pending |
| 17 | Data saving / Cloud Boost | Package | Pending |
| 18 | Download manager: pause/resume, retry, concurrency and folders | Screen / Package | UI placeholder |
| 19 | Social-media/video downloader | Screen / Package | Pending |
| 20 | Torrent-resource downloads | Package | Pending |
| 21 | Video player: speed, background playback and floating player | Package | Pending |
| 22 | Local video/audio/photo library | Package | Pending |
| 23 | File browser and archive extraction | Package | Pending |
| 24 | Private Space for files/videos | Package | Pending |
| 25 | Saved/offline pages, text reading and reading content | Package | Pending |
| 26 | Translation | Package | Pending |
| 27 | Forms/password autofill and typing assistant | Screen / Package | Pending |
| 28 | Clipboard manager | Package | Pending |
| 29 | QR/barcode scanner | Package | Pending |
| 30 | UC account and third-party sign-in | Screen / Package | Pending |
| 31 | Cloud bookmark sync and backup across devices | Package | Pending |
| 32 | UC Drive: cloud files, uploads, offline downloads, sharing and paid tiers | Package | Pending |
| 33 | Built-in VPN and VPN settings | Screen / Package | Pending |
| 34 | Ask AI / AI chat | Screen / Package | Pending |
| 35 | AI Notes | Screen / Package | Pending |
| 36 | News/content feeds and recommendations | Package | Pending |
| 37 | Story/novel and entertainment shortcuts | Screen / Package | Pending |
| 38 | Games and promotional shortcuts | Screen / Package | Pending |
| 39 | Notifications and background services | Screen / Package | Pending |
| 40 | Default-browser setup and Android sharing | Screen / Package | Pending |
| 41 | Connect/play on PC | Package | Pending |
| 42 | Storage cleaning tools | Package | Pending |
| 43 | Feedback, help, about and update flows | Screen / Package | Pending |
| 44 | Website safety/security prompts | Package | Pending |
| 45 | Advertising, ad mediation and sponsored placements | Package | Pending; not included in Crock |
| 46 | Usage analytics, advertising attribution, telemetry and crash reporting | Package | Pending; not included in Crock |

The subsequently approved scope supersedes the original selection column above. Accounts, cloud backup/sync, VPN, AI, content feeds, promotions, advertising and usage analytics were excluded. See the current status document for implementation and validation limits.

## Reference screens and source

- Original UI captures: `../analysis/screenshots/02-welcome.png`, `06-home.png`, `07-menu.png`, `08-settings.png`, `09-browsing-settings.png`, `11-download-settings.png`, `12-search-settings.png`, `13-ad-settings.png`.
- Recovered English UI strings: `../analysis/raw/uc-english-strings.json`.
- Recovered Java: `../analysis/jadx/sources/` and `../analysis/jadx-audience-network/sources/`.
- Recovered resources and manifest: `../analysis/decoded/`.

Decompiled material stays outside the Android app source set. Crock Browser uses newly written Flutter/Dart UI, Java services and Android WebView.
