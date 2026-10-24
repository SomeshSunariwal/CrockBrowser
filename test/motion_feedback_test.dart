import 'package:crockbrowser/shared/widgets/crock_notification.dart';
import 'package:crockbrowser/shared/widgets/feature_scaffold.dart';
import 'package:crockbrowser/shared/widgets/sliding_address_bar.dart';
import 'package:crockbrowser/core/storage/browser_store.dart';
import 'package:crockbrowser/features/browser/browser_controller.dart';
import 'package:crockbrowser/features/browser/widgets/browser_address_bar.dart';
import 'package:crockbrowser/features/tabs/tabs_screen.dart';
import 'package:crockbrowser/features/tabs/widgets/browser_tab_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('slow toolbar slide preserves the browser viewport size', (
    tester,
  ) async {
    final motion = AnimationController(vsync: tester, value: 1);
    const page = ValueKey('native-page-size');
    const toolbar = ValueKey('scroll-toolbar');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LayoutBuilder(
            builder: (_, viewport) => Column(
              children: [
                SlidingAddressBar(
                  visibility: motion,
                  child: const SizedBox(
                    key: toolbar,
                    height: 56,
                    width: double.infinity,
                  ),
                ),
                Expanded(
                  child: StableBrowserViewport(
                    height: viewport.maxHeight,
                    child: const SizedBox(key: page, width: double.infinity),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final initialSize = tester.getSize(find.byKey(page));
    for (var pixels = 1; pixels <= 56; pixels++) {
      motion.value = 1 - pixels / 56;
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getSize(find.byKey(page)), initialSize);
      expect(
        tester.getTopLeft(find.byKey(toolbar)).dy,
        closeTo(-pixels.toDouble(), .01),
      );
      expect(
        tester.getTopLeft(find.byKey(page)).dy,
        closeTo(56 - pixels.toDouble(), .01),
      );
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    motion.dispose();
  });

  testWidgets(
    'browser menu stays unobstructed by current and incoming banners',
    (tester) async {
      final controller = TextEditingController();
      final focus = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => CrockNotificationHost(child: child!),
          home: Scaffold(
            body: BrowserAddressBar(
              controller: controller,
              focusNode: focus,
              url: 'https://example.com',
              onHome: () {},
              onSubmit: (_) {},
              onMenuSelected: (_) {},
              onTabs: () {},
              tabCount: 1,
            ),
          ),
        ),
      );
      crockNotification.value = 'File added to downloads';
      await tester.pumpAndSettle();
      expect(find.text('File added to downloads'), findsOneWidget);
      await tester.tap(find.byTooltip('More browser options'));
      await tester.pumpAndSettle();
      expect(find.text('New Tab'), findsOneWidget);
      expect(find.text('File added to downloads'), findsNothing);
      crockNotification.value = 'Download completed';
      await tester.pumpAndSettle();
      expect(find.text('Download completed'), findsNothing);
      await tester.tap(find.text('New Tab'));
      await tester.pumpAndSettle();
      expect(find.text('Download completed'), findsOneWidget);
      await tester.tap(find.byTooltip('More browser options'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 400));
      await tester.pumpAndSettle();
      expect(crockNotificationObscured.value, isFalse);
      expect(find.text('Download completed'), findsOneWidget);
      crockNotification.value = null;
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      focus.dispose();
    },
  );

  for (final grid in [true, false]) {
    for (final right in [true, false]) {
      testWidgets(
        'tab swipe ${right ? 'right' : 'up'} fades and closes in ${grid ? 'grid' : 'list'} view',
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
          final store = BrowserStore(true);
          store.data['settings'] = {'tabGrid': grid};
          final browser = BrowserController(store)..newTab();
          await tester.pumpWidget(
            MaterialApp(home: TabsScreen(browser: browser)),
          );
          await tester.pumpAndSettle();
          final card = find.byType(BrowserTabCard).first;
          final size = tester.getSize(card);
          final gesture = await tester.startGesture(tester.getCenter(card));
          final movement = right
              ? Offset(size.width * .4, 0)
              : Offset(0, -size.height * .4);
          await gesture.moveBy(movement);
          await tester.pump();
          await gesture.moveBy(movement);
          await tester.pump();
          final fade = find
              .ancestor(of: card, matching: find.byType(Opacity))
              .first;
          expect(tester.widget<Opacity>(fade).opacity, lessThan(1));
          await gesture.up();
          await tester.pumpAndSettle();
          expect(browser.tabs.length, 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          browser.dispose();
          store.dispose();
        },
      );
    }
  }
  testWidgets(
    'address bar translates through the top edge and eases back down',
    (tester) async {
      final motion = AnimationController(vsync: tester, value: 1);
      const barKey = ValueKey('sliding-bar');
      const contentKey = ValueKey('toolbar-content');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SlidingAddressBar(
                  key: barKey,
                  visibility: motion,
                  child: const SizedBox(
                    key: contentKey,
                    height: 56,
                    width: double.infinity,
                  ),
                ),
                const Expanded(child: SizedBox()),
              ],
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byKey(barKey)).height, 56);
      motion.value = .5;
      await tester.pump();
      expect(tester.getSize(find.byKey(barKey)).height, 28);
      expect(tester.getTopLeft(find.byKey(contentKey)).dy, -28);
      motion.value = 0;
      await tester.pump();
      expect(tester.getSize(find.byKey(barKey)).height, 0);
      motion.animateTo(
        1,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final intermediate = tester.getSize(find.byKey(barKey)).height;
      expect(intermediate, greaterThan(0));
      expect(intermediate, lessThan(56));
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byKey(barKey)).height, 56);
      await tester.pumpWidget(const SizedBox());
      motion.dispose();
    },
  );

  testWidgets('in-app banner fades during upward swipe and dismisses', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => CrockNotificationHost(child: child!),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => crockMessage(context, 'Swipe this notification'),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Swipe this notification')),
    );
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    final fade = find.descendant(
      of: find.byType(Dismissible),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(fade).opacity, lessThan(1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Swipe this notification'), findsNothing);
    expect(crockNotification.value, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
