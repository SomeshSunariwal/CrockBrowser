import 'dart:async';

import 'package:crockbrowser/core/storage/browser_store.dart';
import 'package:crockbrowser/core/theme/crock_theme.dart';
import 'package:crockbrowser/features/browser/browser_controller.dart';
import 'package:crockbrowser/features/settings/widgets/appearance_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'text size commits once on release and brightness keeps the latest value',
    (tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      final gate = Completer<void>();
      final brightnessWrites = <double>[];
      var fontWrites = 0;
      messenger.setMockMethodCallHandler(
        const MethodChannel('croc/events'),
        (call) async => null,
      );
      messenger.setMockMethodCallHandler(const MethodChannel('croc/native'), (
        call,
      ) async {
        if (call.method == 'device.brightness') {
          brightnessWrites.add(
            ((call.arguments as Map)['value'] as num).toDouble(),
          );
          if (brightnessWrites.length == 1) await gate.future;
        }
        return null;
      });
      messenger.setMockMethodCallHandler(
        const MethodChannel('croc/webview/42'),
        (call) async {
          if (call.method == 'settings') fontWrites++;
          return null;
        },
      );
      final store = BrowserStore(false);
      final browser = BrowserController(store);
      browser.attach(42, browser.current);
      await tester.pumpWidget(
        MaterialApp(
          theme: CrockTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AppearancePanel(browser: browser),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Text size'));
      await tester.pumpAndSettle();
      final textSlider = tester.widget<Slider>(
        find.byKey(const ValueKey('text-size-slider')),
      );
      textSlider.onChanged!(140);
      textSlider.onChanged!(160);
      await tester.pump();
      expect(store.setting('font', 100), 100);
      expect(fontWrites, 0);
      textSlider.onChangeEnd!(160);
      await tester.pumpAndSettle();
      expect(store.setting('font'), 160);
      expect(fontWrites, 1);
      await tester.tap(find.text('Brightness'));
      await tester.pumpAndSettle();
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('brightness-slider')),
      );
      slider.onChanged!(.2);
      slider.onChanged!(.5);
      slider.onChanged!(.8);
      await tester.pump();
      expect(brightnessWrites, [.2]);
      gate.complete();
      await tester.pumpAndSettle();
      expect(brightnessWrites, [.2, .8]);
      expect(store.setting('brightness'), .8);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      browser.dispose();
      await store.flush();
      store.dispose();
    },
  );
  testWidgets('appearance sliders expand and collapse smoothly in place', (
    tester,
  ) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('croc/native'),
      (call) async => null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('croc/events'),
      (call) async => null,
    );
    final store = BrowserStore(false);
    final browser = BrowserController(store);
    await tester.pumpWidget(
      MaterialApp(
        theme: CrockTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(child: AppearancePanel(browser: browser)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Slider), findsNothing);
    final below = find.text('Screen orientation');
    for (final title in ['Text size', 'Brightness']) {
      final collapsed = tester.getTopLeft(below).dy;
      await tester.tap(find.text(title));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final halfway = tester.getTopLeft(below).dy;
      await tester.pumpAndSettle();
      final expanded = tester.getTopLeft(below).dy;
      expect(halfway, greaterThan(collapsed));
      expect(halfway, lessThan(expanded));
      await tester.tap(find.text(title));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.getTopLeft(below).dy, lessThan(expanded));
      expect(tester.getTopLeft(below).dy, greaterThan(collapsed));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(below).dy, closeTo(collapsed, .01));
      expect(find.byType(Slider), findsNothing);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    browser.dispose();
    await store.flush();
    store.dispose();
    messenger.setMockMethodCallHandler(
      const MethodChannel('croc/native'),
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('croc/events'),
      null,
    );
  });
}
