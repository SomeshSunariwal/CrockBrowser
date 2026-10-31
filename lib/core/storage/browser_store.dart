import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../platform/native_bridge.dart';

typedef BrowserRows = List<Map<String, dynamic>>;

/// Persisted metadata stays on the device. Private sessions never save tabs/history.
class BrowserStore extends ChangeNotifier {
  BrowserStore(this.privateMode);
  final bool privateMode;
  final Map<String, dynamic> data = {};
  Timer? _write;
  final Set<String> _dirty = {};
  final Set<String> _settingsDirty = {};
  String? saveError;
  Map<String, dynamic> get settings {
    final value = data['settings'];
    return value is Map<String, dynamic>
        ? value
        : (value as Map?)?.cast<String, dynamic>() ?? const {};
  }

  final _rowCache = <String, (Object?, List<Map<String, dynamic>>)>{};

  /// Stable, read-only snapshots for selectors and rendering. Mutations continue
  /// to use rows(), so UI code cannot accidentally change persisted records.
  /// In-place edits through data must call changed(keys: [key]).
  List<Map<String, dynamic>> readRows(String key) {
    final source = data[key];
    final cached = _rowCache[key];
    if (cached != null && identical(source, cached.$1)) return cached.$2;
    final rows = List<Map<String, dynamic>>.unmodifiable(
      ((source as List?) ?? const []).map(
        (row) => Map<String, dynamic>.unmodifiable(row as Map),
      ),
    );
    _rowCache[key] = (source, rows);
    return rows;
  }

  List<Map<String, dynamic>> rows(String key) =>
      readRows(key).map((row) => Map<String, dynamic>.from(row)).toList();

  Future<void> load() async {
    final text = await NativeBridge.instance.call<String>('store.read') ?? '{}';
    data.addAll(Map<String, dynamic>.from(jsonDecode(text) as Map));
    data.putIfAbsent('settings', () => <String, dynamic>{});
    if (privateMode) {
      data.remove('tabs');
      data.remove('history');
    }
    if (rows('engines').isEmpty) {
      data['engines'] = [
        {
          'id': 'google',
          'name': 'Google',
          'url': 'https://www.google.com/search?q={query}',
        },
        {
          'id': 'duck',
          'name': 'DuckDuckGo',
          'url': 'https://duckduckgo.com/?q={query}',
        },
        {
          'id': 'bing',
          'name': 'Bing',
          'url': 'https://www.bing.com/search?q={query}',
        },
        {
          'id': 'brave',
          'name': 'Brave',
          'url': 'https://search.brave.com/search?q={query}',
        },
      ];
      _dirty.add('engines');
    }
    if (data['shortcuts'] == null) {
      data['shortcuts'] = [
        {'id': 'google', 'title': 'Google', 'url': 'https://google.com'},
        {'id': 'youtube', 'title': 'YouTube', 'url': 'https://m.youtube.com'},
        {'id': 'wiki', 'title': 'Wikipedia', 'url': 'https://wikipedia.org'},
        {'id': 'reddit', 'title': 'Reddit', 'url': 'https://reddit.com'},
      ];
      _dirty.add('shortcuts');
    }
  }

  dynamic setting(String key, [dynamic fallback]) => settings[key] ?? fallback;
  void setSetting(String key, dynamic value) {
    if (settings.containsKey(key) && settings[key] == value) return;
    final next = Map<String, dynamic>.from(settings)..[key] = value;
    data['settings'] = next;
    _settingsDirty.add(key);
    changed();
  }

  void setRows(String key, List<Map<String, dynamic>> value) {
    if (privateMode && (key == 'tabs' || key == 'history')) return;
    data[key] = value;
    _dirty.add(key);
    changed();
  }

  void add(
    String key,
    Map<String, dynamic> row, {
    int? limit,
    bool prepend = true,
  }) {
    if (privateMode && (key == 'history' || key == 'tabs')) return;
    final items = List<Map<String, dynamic>>.of(readRows(key));
    final index = items.indexWhere((item) => item['id'] == row['id']);
    if (!prepend && index >= 0) {
      items[index] = row;
    } else {
      items.removeWhere((item) => item['id'] == row['id']);
      if (prepend) {
        items.insert(0, row);
      } else {
        items.add(row);
      }
    }
    setRows(key, limit == null ? items : items.take(limit).toList());
  }

  void remove(String key, String id) =>
      setRows(key, readRows(key).where((item) => item['id'] != id).toList());
  void changed({
    Iterable<String> keys = const [],
    Iterable<String> settingsKeys = const [],
  }) {
    for (final key in keys) {
      _rowCache.remove(key);
    }
    _dirty.addAll(keys);
    _settingsDirty.addAll(settingsKeys);
    notifyListeners();
    _write?.cancel();
    _write = Timer(const Duration(milliseconds: 250), flush);
  }

  Future<void> flush() async {
    _write?.cancel();
    if (_dirty.isEmpty && _settingsDirty.isEmpty) return;
    final dirty = Set<String>.from(_dirty),
        settingsDirty = Set<String>.from(_settingsDirty);
    _dirty.clear();
    _settingsDirty.clear();
    final snapshot = Map<String, dynamic>.from(data);
    if (privateMode) {
      snapshot.remove('tabs');
      snapshot.remove('history');
    }
    try {
      await NativeBridge.instance.call('store.write', {
        'json': jsonEncode(snapshot),
        'private': privateMode,
        'keys': dirty.toList(),
        'settingsKeys': settingsDirty.toList(),
      });
      saveError = null;
    } catch (error) {
      _dirty.addAll(dirty);
      _settingsDirty.addAll(settingsDirty);
      saveError = error.toString();
      notifyListeners();
    }
  }

  Future<void> reloadShared() async {
    final text = await NativeBridge.instance.call<String>('store.read') ?? '{}';
    final latest = Map<String, dynamic>.from(jsonDecode(text) as Map);
    for (final key in [
      'bookmarks',
      'folders',
      'engines',
      'shortcuts',
      'clips',
    ]) {
      if (!_dirty.contains(key) && latest.containsKey(key)) {
        data[key] = latest[key];
      }
    }
    final preferences = Map<String, dynamic>.from(
      latest['settings'] as Map? ?? {},
    );
    for (final key in _settingsDirty) {
      preferences[key] = settings[key];
    }
    data['settings'] = preferences;
    notifyListeners();
  }

  @override
  void dispose() {
    _write?.cancel();
    super.dispose();
  }
}
