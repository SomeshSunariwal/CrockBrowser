import 'dart:async';

import 'package:crockbrowser/core/models/browser_tab.dart';
import 'package:crockbrowser/core/storage/browser_store.dart';
import 'package:crockbrowser/features/browser/browser_controller.dart';
import 'package:crockbrowser/shared/widgets/selected_builder.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('late thumbnail results are ignored after disposal', (
    tester,
  ) async {
    final result = Completer<Uint8List?>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('croc/webview/42'),
      (call) async => call.method == 'captureThumbnail' ? result.future : null,
    );
    final store = BrowserStore(false);
    final browser = BrowserController(store);
    final tab = browser.current
      ..url = 'https://example.com'
      ..atHome = false;
    browser.attach(42, tab);
    final pending = browser.captureThumbnails();
    await tester.pump();
    browser.dispose();
    result.complete(Uint8List(4));
    await pending;
    expect(tab.thumbnail, isNull);
    expect(tester.takeException(), isNull);
    store.dispose();
  });
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('croc/native'),
      (call) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('croc/events'),
      (call) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('croc/webview/42'),
      (call) async => null,
    );
  });

  testWidgets(
    'identical page events do not rewrite history or rebuild the browser',
    (tester) async {
      final store = BrowserStore(false);
      final browser = BrowserController(store);
      final tab = browser.current
        ..url = 'https://example.com'
        ..atHome = false;
      browser.attach(42, tab);
      await tester.pump();
      Future<void> emit(Map<String, Object> event) async {
        await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
          'croc/events',
          const StandardMethodCodec().encodeSuccessEnvelope(event),
          (_) {},
        );
        await tester.pump();
      }

      final state = <String, Object>{
        'type': 'browser',
        'view': 42,
        'url': tab.url,
        'title': 'Example',
        'progress': 100,
        'failed': false,
        'back': false,
        'forward': false,
      };
      await emit(state);
      final history = store.readRows('history');
      var rebuilds = 0, writes = 0;
      browser.addListener(() => rebuilds++);
      store.addListener(() => writes++);
      for (var i = 0; i < 100; i++) {
        await emit(state);
      }
      expect(rebuilds, 0);
      expect(writes, 0);
      expect(identical(store.readRows('history'), history), isTrue);
      await emit({...state, 'back': true});
      expect(rebuilds, 1);
      expect(writes, 0);
      expect(browser.current.canBack, isTrue);
      browser.dispose();
      await store.flush();
      store.dispose();
    },
  );

  testWidgets('close all releases unused data and publishes once', (
    tester,
  ) async {
    final store = BrowserStore(false);
    final browser = BrowserController(store);
    browser.tabs.clear();
    for (var i = 0; i < 100; i++) {
      final tab =
          BrowserTab(id: '$i', url: 'https://example.com/$i', title: 'Tab $i')
            ..atHome = false
            ..thumbnail = Uint8List(4096);
      browser.tabs.add(tab);
      browser.foundMedia[tab.id] = [
        {'url': 'https://example.com/video$i.mp4'},
      ];
    }
    var changes = 0, writes = 0;
    browser.addListener(() => changes++);
    store.addListener(() => writes++);
    browser.closeAll();
    expect(changes, 1);
    expect(writes, 1);
    expect(browser.tabs.single.atHome, isTrue);
    expect(browser.foundMedia, isEmpty);
    expect(browser.closedTabs, hasLength(100));
    expect(browser.closedTabs.every((tab) => tab.thumbnail == null), isTrue);
    browser.reopenClosed();
    expect(browser.current.title, 'Tab 0');
    browser.dispose();
    await store.flush();
    store.dispose();
  });

  testWidgets('settings coalesce to latest value and tolerate a tab closing', (
    tester,
  ) async {
    final store = BrowserStore(false);
    final browser = BrowserController(store);
    browser.attach(42, browser.current);
    final applied = <int>[];
    var gate = Completer<void>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('croc/webview/42'),
      (call) async {
        if (call.method == 'settings') {
          applied.add((call.arguments as Map)['font'] as int);
          if (applied.length == 1 || applied.last == 200) await gate.future;
        }
        return null;
      },
    );
    final first = browser.updateSettings();
    await tester.pump();
    store.setSetting('font', 120);
    browser.updateSettings();
    store.setSetting('font', 150);
    browser.updateSettings();
    gate.complete();
    await first;
    expect(applied, [100, 150]);
    gate = Completer<void>();
    store.setSetting('font', 200);
    final pending = browser.updateSettings();
    await tester.pump();
    browser.close(0);
    gate.complete();
    await pending;
    expect(tester.takeException(), isNull);
    browser.dispose();
    await store.flush();
    store.dispose();
  });

  testWidgets('selected listenable ignores unrelated slider values', (
    tester,
  ) async {
    final store = BrowserStore(false);
    final projection = SelectedValue(store, () => store.readRows('shortcuts'));
    var changes = 0;
    projection.addListener(() => changes++);
    for (var i = 0; i < 100; i++) {
      store.setSetting('brightness', i / 100);
    }
    expect(changes, 0);
    store.setRows('shortcuts', [
      {'id': 'one', 'url': 'https://example.com'},
    ]);
    expect(changes, 1);
    projection.dispose();
    store.setRows('shortcuts', []);
    await store.flush();
    store.dispose();
  });
}
