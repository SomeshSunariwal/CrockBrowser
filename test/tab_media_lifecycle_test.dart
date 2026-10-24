import 'package:crockbrowser/core/storage/browser_store.dart';
import 'package:crockbrowser/features/browser/browser_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'only the visible page is active; overview and home suspend media',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('croc/events'),
        (_) async => null,
      );
      messenger.setMockMethodCallHandler(
        const MethodChannel('croc/native'),
        (_) async => null,
      );
      final activity = <int, bool>{};
      final calls = <String>[];
      for (final view in [1, 2, 3]) {
        messenger.setMockMethodCallHandler(
          MethodChannel('croc/webview/$view'),
          (call) async {
            calls.add('$view:${call.method}');
            if (call.method == 'setActive') {
              activity[view] = call.arguments['active'] == true;
            }
            return null;
          },
        );
      }
      final store = BrowserStore(false);
      final browser = BrowserController(store);
      await browser.open('https://example.com/video');
      browser.attach(1, browser.current);
      await tester.pump();
      expect(activity[1], isTrue);
      browser.newTab('https://example.com/other-video');
      browser.attach(2, browser.current);
      await tester.pump();
      expect(activity, {1: false, 2: true});
      await browser.setTabOverviewVisible(true);
      expect(activity, {1: false, 2: false});
      browser.select(0);
      await tester.pump();
      expect(activity, {1: false, 2: false});
      await browser.setTabOverviewVisible(false);
      expect(activity, {1: true, 2: false});
      browser.select(1);
      await tester.pump();
      expect(activity, {1: false, 2: true});
      browser.home();
      await tester.pump();
      expect(activity, {1: false, 2: false});
      await browser.forward();
      expect(activity[2], isTrue);
      browser.close(1);
      await tester.pump();
      expect(activity, {1: true, 2: false});
      browser.reopenClosed();
      browser.attach(3, browser.current);
      await tester.pump();
      expect(activity, {1: false, 2: false, 3: true});
      expect(calls.where((call) => call.contains('play')), isEmpty);
      browser.dispose();
      store.dispose();
      await tester.pump();
    },
  );
}
