import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/models/browser_tab.dart';
import '../../core/platform/native_bridge.dart';
import '../../core/storage/browser_store.dart';
import '../../core/services/site_icons.dart';

class BrowserController extends ChangeNotifier {
  BrowserController(this.store) {
    if (!store.privateMode && store.setting('restoreTabs', true) == true) {
      tabs.addAll(store.rows('tabs').map(BrowserTab.fromMap));
    }
    if (tabs.isEmpty) tabs.add(BrowserTab());
    selected = (store.setting('selectedTab', 0) as int).clamp(
      0,
      tabs.length - 1,
    );
    _events = NativeBridge.instance.events.listen(_event);
  }
  final BrowserStore store;
  final List<BrowserTab> tabs = [];
  final List<BrowserTab> closedTabs = [];
  final Map<int, String> _ids = {};
  final Map<String, MethodChannel> _channels = {};
  final Map<String, Rect? Function()> _thumbnailBounds = {};
  final Map<String, Future<void>> _capturingThumbnails = {};
  final Set<String> _thumbnailCapturedForLoad = {};
  final Map<String, String> _pendingOffline = {};
  final Map<String, double> _scrollY = {}, _scrollDirection = {};
  final Map<String, bool> _scrollable = {};
  final Map<String, List<Map<String, dynamic>>> foundMedia = {};
  late StreamSubscription<Map<String, dynamic>> _events;
  final events = StreamController<Map<String, dynamic>>.broadcast();
  int selected = 0;
  bool _tabOverviewVisible = false;
  BrowserTab get current => tabs[selected];
  bool isTabActive(BrowserTab tab) =>
      !_tabOverviewVisible && tab == current && !tab.atHome;

  Future<void> setTabOverviewVisible(bool visible) async {
    _tabOverviewVisible = visible;
    await _syncTabActivity();
  }

  Future<void> _setTabActivity(BrowserTab tab, {bool? active}) async {
    try {
      await _channels[tab.id]?.invokeMethod('setActive', {
        'active': active ?? isTabActive(tab),
      });
    } on PlatformException {
      // Closing a tab can dispose its native view before this call arrives.
    } on MissingPluginException {
      // A native view may be detached while the tab list is changing.
    }
  }

  Future<void> _syncTabActivity() async {
    // Suspend hidden tabs before making the selected tab active.
    for (final tab in tabs.where((tab) => !isTabActive(tab)).toList()) {
      await _setTabActivity(tab);
    }
    if (isTabActive(current)) await _setTabActivity(current);
  }

  bool get privateMode => store.privateMode;
  bool get darkTheme {
    final legacy = store.setting('darkTheme', false) == true;
    return switch (store.setting('themeMode', legacy ? 'dark' : 'system')) {
      'dark' => true,
      'light' => false,
      _ =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark,
    };
  }

  void attach(int view, BrowserTab tab, {Rect? Function()? thumbnailBounds}) {
    _ids[view] = tab.id;
    _channels[tab.id] = MethodChannel('croc/webview/$view');
    if (thumbnailBounds != null) _thumbnailBounds[tab.id] = thumbnailBounds;
    unawaited(_setTabActivity(tab));
    final offline = _pendingOffline.remove(tab.id);
    if (offline != null) {
      _channels[tab.id]!.invokeMethod('openOffline', {'path': offline});
    }
  }

  Future<void> captureThumbnails({bool refresh = false}) async {
    final tab = current;
    if (tab.atHome) return;
    final pending = _capturingThumbnails[tab.id];
    if (pending != null) {
      await pending;
      if (!refresh || current != tab || !tabs.contains(tab)) return;
    }
    final channel = _channels[tab.id];
    if (channel == null) return;
    final capture = _captureThumbnail(tab, channel);
    _capturingThumbnails[tab.id] = capture;
    try {
      await capture;
    } finally {
      if (_capturingThumbnails[tab.id] == capture) {
        _capturingThumbnails.remove(tab.id);
      }
    }
  }

  Future<void> _captureThumbnail(BrowserTab tab, MethodChannel channel) async {
    try {
      final bounds = _thumbnailBounds[tab.id]?.call();
      final image = await channel.invokeMethod<Uint8List>(
        'captureThumbnail',
        bounds == null
            ? null
            : {
                'left': bounds.left.round(),
                'top': bounds.top.round(),
                'right': bounds.right.round(),
                'bottom': bounds.bottom.round(),
              },
      );
      if (image != null && tabs.contains(tab)) {
        tab.thumbnail = image;
        notifyListeners();
      }
    } on PlatformException {
      // The view may be disposed while Android is drawing the preview.
    } on MissingPluginException {
      // The native view can disappear before its channel responds.
    }
  }

  Future<dynamic> page(String method, [Map<String, dynamic>? args]) async =>
      _channels[current.id]?.invokeMethod(method, args);

  void userScroll(BrowserTab tab, double delta) {
    if (tab != current ||
        tab.atHome ||
        delta == 0 ||
        _scrollable[tab.id] == false) {
      return;
    }
    _scrollDirection[tab.id] = delta.sign;
    events.add({
      'type': 'scroll',
      'source': 'touch',
      'deltaY': delta,
      'y': _scrollY[tab.id] ?? 0,
    });
  }

  void _event(Map<String, dynamic> event) {
    final id = _ids[event['view']];
    final matches = tabs.where((tab) => tab.id == id);
    final tab = matches.isEmpty ? null : matches.first;
    switch (event['type']) {
      case 'loginSuggestion':
        if (!privateMode && tab == current && !current.atHome) {
          events.add(event);
        }
      case 'favicon':
        if (!privateMode &&
            event['url'] is String &&
            event['bytes'] is Uint8List) {
          SiteIcons.remember(
            event['url'] as String,
            event['bytes'] as Uint8List,
          );
        }
      case 'browser':
        if (tab == null) return;
        tab.url = event['url'] as String? ?? tab.url;
        tab.title = event['title'] as String? ?? tab.title;
        tab.progress = ((event['progress'] as num?) ?? 0) / 100;
        tab.loading = tab.progress < 1;
        if (tab.loading) _thumbnailCapturedForLoad.remove(tab.id);
        tab.failed = event['failed'] == true;
        tab.canBack = event['back'] == true;
        tab.canForward = event['forward'] == true;
        if (!tab.loading &&
            !tab.failed &&
            !tab.atHome &&
            tab.url.startsWith('http')) {
          store.add('history', {
            'id': tab.url,
            'url': tab.url,
            'title': tab.title,
            'created': DateTime.now().millisecondsSinceEpoch,
          }, limit: 2000);
        }
        notifyListeners();
        if (tab == current &&
            !tab.loading &&
            !tab.failed &&
            !tab.atHome &&
            _thumbnailCapturedForLoad.add(tab.id)) {
          captureThumbnails();
        }
        if (!tab.loading) persist();
      case 'scroll':
        if (tab == null) return;
        if (event['y'] is num) {
          _scrollY[tab.id] = (event['y'] as num).toDouble();
        }
        if (event['canScroll'] is bool) {
          _scrollable[tab.id] = event['canScroll'] as bool;
        }
        if (event['source'] == 'page') return;
        if (event['source'] == 'fling' &&
            (event['deltaY'] as num).sign != _scrollDirection[tab.id]) {
          return;
        }
        if (tab == current && !current.atHome) events.add(event);
        return;
      case 'media':
        if (id != null) {
          final media = foundMedia.putIfAbsent(id, () => []);
          if (!media.any((row) => row['url'] == event['url'])) media.add(event);
        }
      case 'newTab':
        newTab(event['url'] as String?);
      default:
        events.add(event);
    }
  }

  String resolve(String input, {String? engine}) {
    final text = input.trim();
    final possible = Uri.tryParse(
      text.contains('://') ? text : 'https://$text',
    );
    if (!text.contains(RegExp(r'\s')) &&
        possible != null &&
        ['http', 'https'].contains(possible.scheme) &&
        possible.userInfo.isEmpty &&
        (possible.host.contains('.') || possible.host == 'localhost')) {
      return possible.toString();
    }
    final engines = store.rows('engines');
    final name = engine ?? store.setting('engine', 'google');
    final selected = engines.where((item) => item['id'] == name);
    final template = selected.isEmpty
        ? 'https://www.google.com/search?q={query}'
        : selected.first['url'] as String;
    return template.replaceAll('{query}', Uri.encodeComponent(text));
  }

  Future<void> open(String input, {bool resolved = false}) async {
    if (input.trim().isEmpty) return;
    final url = resolved ? input : resolve(input);
    final uri = Uri.tryParse(url);
    if (uri == null || !['http', 'https'].contains(uri.scheme)) {
      throw ArgumentError('Use an HTTP or HTTPS address');
    }
    current.url = url;
    current.desktop = _desktopFor(url);
    current.atHome = false;
    current.failed = false;
    await _syncTabActivity();
    foundMedia[current.id] = [];
    await _channels[current.id]?.invokeMethod('settings', {
      'desktop': current.desktop,
    });
    await _channels[current.id]?.invokeMethod('load', {'url': url});
    notifyListeners();
    persist();
  }

  void newTab([String? url]) {
    tabs.add(BrowserTab());
    selected = tabs.length - 1;
    if (url != null && url.isNotEmpty) {
      current.url = resolve(url);
      current.desktop = _desktopFor(current.url);
      current.atHome = false;
    }
    unawaited(_syncTabActivity());
    notifyListeners();
    persist();
  }

  void select(int index) {
    selected = index;
    unawaited(_syncTabActivity());
    notifyListeners();
    persist();
  }

  void close(int index) {
    final closingChannel = _channels[tabs[index].id];
    if (closingChannel != null) {
      unawaited(_setTabActivity(tabs[index], active: false));
    }
    final removed = tabs.removeAt(index);
    _thumbnailBounds.remove(removed.id);
    _scrollY.remove(removed.id);
    _scrollDirection.remove(removed.id);
    _scrollable.remove(removed.id);
    _thumbnailCapturedForLoad.remove(removed.id);
    if (!privateMode) closedTabs.add(removed);
    _channels.remove(removed.id);
    _ids.removeWhere((key, value) => value == removed.id);
    if (index < selected) selected--;
    if (tabs.isEmpty) tabs.add(BrowserTab());
    selected = selected.clamp(0, tabs.length - 1);
    unawaited(_syncTabActivity());
    notifyListeners();
    persist();
  }

  void reopenClosed() {
    if (closedTabs.isEmpty) return;
    final old = closedTabs.removeLast();
    final restored = BrowserTab(url: old.url, title: old.title)
      ..atHome = old.atHome;
    tabs.add(restored);
    selected = tabs.length - 1;
    unawaited(_syncTabActivity());
    notifyListeners();
    persist();
  }

  void closeAll() {
    while (tabs.length > 1) {
      close(tabs.length - 1);
    }
    close(0);
  }

  void home() {
    current.atHome = true;
    unawaited(_syncTabActivity());
    notifyListeners();
    persist();
  }

  Future<void> back() async {
    if (current.canBack && !current.atHome) {
      await page('back');
    } else {
      home();
    }
  }

  Future<void> forward() async {
    if (current.atHome && current.url.isNotEmpty) {
      current.atHome = false;
      await _syncTabActivity();
      notifyListeners();
    } else {
      await page('forward');
    }
  }

  void persist() {
    if (privateMode) return;
    store.data['tabs'] = tabs.map((tab) => tab.toMap()).toList();
    store.data['settings'] = {...store.settings, 'selectedTab': selected};
    store.changed(keys: ['tabs'], settingsKeys: ['selectedTab']);
  }

  Future<void> updateSettings() async {
    for (final channel in _channels.values) {
      await channel.invokeMethod('settings', {
        'font': store.setting('font', 100),
        'darkTheme': darkTheme,
        'adBlock': store.setting('adBlock', false),
        'offerSavePasswords': store.setting('offerSavePasswords', true),
        'passwordPromptBlockedOrigins': store.setting(
          'passwordPromptBlockedOrigins',
          const <String>[],
        ),
      });
    }
  }

  Future<void> toggleDesktop() async {
    current.desktop = !current.desktop;
    final sites = Map<String, dynamic>.from(
      store.setting('desktopSites', const <String, dynamic>{}) as Map,
    );
    final host = Uri.tryParse(current.url)?.host;
    if (host != null && host.isNotEmpty) {
      sites[host] = current.desktop;
      store.setSetting('desktopSites', sites);
    }
    await page('settings', {'desktop': current.desktop});
    await page('reload');
    persist();
    notifyListeners();
  }

  Future<void> openOffline(Map<String, dynamic> entry) async {
    final path = entry['path'] as String;
    current.url = 'about:blank';
    if (_channels.containsKey(current.id)) {
      await page('openOffline', {'path': path});
    } else {
      _pendingOffline[current.id] = path;
    }
    current.atHome = false;
    await _syncTabActivity();
    notifyListeners();
  }

  bool _desktopFor(String url) {
    final sites =
        store.setting('desktopSites', const <String, dynamic>{}) as Map;
    return sites[Uri.tryParse(url)?.host] == true;
  }

  @override
  void dispose() {
    _events.cancel();
    events.close();
    super.dispose();
  }
}
