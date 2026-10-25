import 'dart:async';

import 'package:crockbrowser/core/models/browser_tab.dart';
import 'package:crockbrowser/core/storage/browser_store.dart';
import 'package:crockbrowser/features/browser/browser_controller.dart';
import 'package:crockbrowser/features/tabs/widgets/browser_tab_card.dart';
import 'package:crockbrowser/features/tabs/widgets/tab_window_transition.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'discard a capture that finishes after overview covers the page',
    (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('croc/events'),
        (_) async => null,
      );
      final captured = Completer<Uint8List>();
      var captures = 0;
      messenger.setMockMethodCallHandler(
        const MethodChannel('croc/webview/43'),
        (call) async {
          if (call.method == 'captureThumbnail') {
            captures++;
            return captured.future;
          }
          return null;
        },
      );
      final store = BrowserStore(true);
      final browser = BrowserController(store);
      browser.current.atHome = false;
      browser.attach(43, browser.current);
      await tester.pump();
      final pending = browser.captureThumbnails();
      await tester.pump();
      expect(captures, 1);
      await browser.setTabOverviewVisible(true);
      captured.complete(Uint8List.fromList([1, 2, 3]));
      await pending;
      expect(browser.current.thumbnail, isNull);
      await browser.captureThumbnails(refresh: true);
      expect(captures, 1);
      browser.dispose();
      store.dispose();
      await tester.pump();
    },
  );
  testWidgets('retain preview until Android acknowledges a drawn page', (
    tester,
  ) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('croc/events'),
      (_) async => null,
    );
    final ready = Completer<void>();
    var requestedDraw = false;
    messenger.setMockMethodCallHandler(const MethodChannel('croc/webview/42'), (
      call,
    ) async {
      if (call.method == 'awaitVisualFrame') {
        requestedDraw = true;
        await ready.future;
      }
      return null;
    });
    final store = BrowserStore(true);
    final browser = BrowserController(store);
    browser.current.atHome = false;
    browser.attach(42, browser.current);
    await tester.pump();
    await browser.setTabOverviewVisible(true);
    expect(browser.tabOverviewVisible, isTrue);
    expect(browser.tabSnapshotVisible, isTrue);
    final reveal = browser.setTabOverviewVisible(false);
    await tester.pump();
    await tester.pump();
    expect(browser.tabOverviewVisible, isFalse);
    expect(browser.isTabActive(browser.current), isTrue);
    expect(requestedDraw, isTrue);
    expect(browser.tabSnapshotVisible, isTrue);
    ready.complete();
    await tester.pump();
    await tester.pump();
    await reveal;
    expect(browser.tabSnapshotVisible, isFalse);
    browser.dispose();
    store.dispose();
    await tester.pump();
  });

  testWidgets('tab close control stays outside the flying preview', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            height: 244,
            child: BrowserTabCard(
              tab: BrowserTab(id: 'card'),
              selected: true,
              grid: true,
              previewHero: true,
              onSelect: () {},
              onClose: () {},
            ),
          ),
        ),
      ),
    );
    final hero = find.byKey(tabPreviewHeroKey);
    expect(hero, findsOneWidget);
    expect(
      find.descendant(of: hero, matching: find.byType(IconButton)),
      findsNothing,
    );
    expect(find.byType(IconButton), findsOneWidget);
  });
}
