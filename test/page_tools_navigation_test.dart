import 'package:crockbrowser/core/storage/browser_store.dart';
import 'package:crockbrowser/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Back returns from Page tools to Browser menu before the page', (
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
    await tester.pumpWidget(CrockApp(store: store, downloads: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Page tools'));
    await tester.pumpAndSettle();
    expect(find.text('Reader & translation'), findsOneWidget);
    expect(find.text('Page tools'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Page tools'), findsOneWidget);
    expect(find.text('Reader & translation'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Page tools'), findsNothing);
    expect(find.text('Crock Browser'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
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
