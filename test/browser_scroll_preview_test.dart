import 'dart:async';

import 'package:crockbrowser/core/storage/browser_store.dart';
import 'package:crockbrowser/features/browser/browser_controller.dart';
import 'package:crockbrowser/features/browser/browser_shell.dart';
import 'package:crockbrowser/features/browser/native_browser_surface.dart';
import 'package:crockbrowser/features/browser/widgets/page_scroll_observer.dart';
import 'package:crockbrowser/shared/widgets/sliding_address_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'drag distance stays stable when the observed page moves upward',
    (tester) async {
      final deltas = <double>[];
      var translation = 0.0;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (_, update) => Transform.translate(
              offset: Offset(0, translation),
              child: PageScrollObserver(
                onScroll: (delta) {
                  deltas.add(delta);
                  update(() => translation -= delta);
                },
                child: const ColoredBox(
                  color: Colors.white,
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      );
      final drag = await tester.startGesture(const Offset(200, 300));
      await drag.moveTo(const Offset(200, 270));
      await tester.pump();
      await drag.moveTo(const Offset(200, 268));
      await tester.pump();
      await drag.moveTo(const Offset(200, 266));
      await tester.pump();
      expect(deltas, [30, 2, 2]);
      await drag.moveTo(const Offset(200, 268));
      await tester.pump();
      expect(deltas.last, -2);
      await drag.up();
      await tester.pumpWidget(const SizedBox());
    },
  );

  void mockNative() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('croc/events'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('croc/native'),
      (call) async => call.method.endsWith('.list') ? <Object>[] : null,
    );
  }

  BrowserStore pageStore() => BrowserStore(false)
    ..data.addAll({
      'settings': {'addressBarMode': 'dynamic'},
      'tabs': [
        {'id': 'scroll-test', 'url': 'https://example.com', 'home': false},
      ],
    });

  testWidgets('slow downward drag hides monotonically; upward drag eases in', (
    tester,
  ) async {
    mockNative();
    final store = pageStore();
    await tester.pumpWidget(MaterialApp(home: BrowserShell(store: store)));
    await tester.pumpAndSettle();
    final browser = tester
        .widget<NativeBrowserSurface>(find.byType(NativeBrowserSurface))
        .browser;
    final bar = find.byType(SlidingAddressBar);
    final original = tester.getSize(bar).height;
    var previous = original;
    for (var pixels = 2; pixels <= 120; pixels += 2) {
      browser.events.add({
        'type': 'scroll',
        'source': 'touch',
        'deltaY': 2,
        'y': pixels,
      });
      await tester.pump(const Duration(milliseconds: 32));
      final height = tester.getSize(bar).height;
      expect(height, lessThanOrEqualTo(previous));
      previous = height;
    }
    expect(previous, 0);
    // Finishing an inertial downward scroll must not reveal the bar.
    browser.events.add({
      'type': 'scroll',
      'source': 'fling',
      'deltaY': 4,
      'y': 124,
    });
    await tester.pumpAndSettle();
    expect(tester.getSize(bar).height, 0);
    browser.events.add({
      'type': 'scroll',
      'source': 'touch',
      'deltaY': -2,
      'y': 122,
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getSize(bar).height, greaterThan(0));
    expect(tester.getSize(bar).height, lessThan(original));
    await tester.pumpAndSettle();
    expect(tester.getSize(bar).height, original);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets(
    'overview refresh waits for an in-flight load preview then captures again',
    (tester) async {
      mockNative();
      final store = pageStore();
      final browser = BrowserController(store);
      final firstFrame = Completer<Uint8List>();
      var captures = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('croc/webview/91'), (
            call,
          ) async {
            if (call.method != 'captureThumbnail') return null;
            captures++;
            return captures == 1
                ? firstFrame.future
                : Uint8List.fromList([2, 3, 4]);
          });
      browser.attach(91, browser.current);
      final first = browser.captureThumbnails();
      await tester.pump();
      final refresh = browser.captureThumbnails(refresh: true);
      await tester.pump();
      expect(captures, 1);
      firstFrame.complete(Uint8List.fromList([1]));
      await tester.pump();
      await first;
      await refresh;
      expect(captures, 2);
      expect(browser.current.thumbnail, [2, 3, 4]);
      browser.dispose();
      store.dispose();
      await tester.pump();
    },
  );
}
