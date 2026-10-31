import 'package:crockbrowser/core/storage/browser_store.dart';
import 'package:crockbrowser/features/browser/browser_controller.dart';
import 'package:crockbrowser/features/browser/browser_shell.dart';
import 'package:crockbrowser/features/browser/native_browser_surface.dart';
import 'package:crockbrowser/main.dart';
import 'package:crockbrowser/shared/widgets/crock_dropdown.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'loading progress never changes webpage bounds; media list stays lazy',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final messenger = tester.binding.defaultBinaryMessenger;
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
        (call) async => call.method == 'media'
            ? List.generate(
                2000,
                (i) => {
                  'title': 'Video $i',
                  'url': 'https://example.com/video$i.mp4',
                },
              )
            : null,
      );
      final store = BrowserStore(false);
      await tester.pumpWidget(CrockApp(store: store, downloads: false));
      await tester.pumpAndSettle();
      final dynamic shell = tester.state(find.byType(BrowserShell));
      final BrowserController browser = shell.browser;
      await browser.open('https://example.com');
      browser.attach(42, browser.current);
      await tester.pumpAndSettle();
      final surface = find.byType(NativeBrowserSurface);
      final bounds = tester.getRect(surface);
      Future<void> progress(int value) async {
        await messenger.handlePlatformMessage(
          'croc/events',
          const StandardMethodCodec().encodeSuccessEnvelope({
            'type': 'browser',
            'view': 42,
            'url': 'https://example.com',
            'title': 'Example',
            'progress': value,
          }),
          (_) {},
        );
        await tester.pumpAndSettle();
      }

      await progress(35);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(tester.getRect(surface), bounds);
      await progress(100);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(tester.getRect(surface), bounds);
    await tester.tap(find.byType(CrockPopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Browser Menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Page tools'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Page media / downloader'));
      await tester.pumpAndSettle();
      expect(find.text('Video 0'), findsOneWidget);
      expect(find.text('Video 1999'), findsNothing);
      expect(find.byType(ListTile).evaluate().length, lessThan(25));
      await tester.drag(find.byType(ListView), const Offset(0, -1200));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile).evaluate().length, lessThan(25));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await store.flush();
      store.dispose();
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
