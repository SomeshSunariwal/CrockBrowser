import 'package:crockbrowser/core/services/site_icons.dart';
import 'package:crockbrowser/core/storage/browser_store.dart';
import 'package:crockbrowser/core/theme/crock_theme.dart';
import 'package:crockbrowser/features/settings/widgets/profile_card.dart';
import 'package:crockbrowser/shared/widgets/site_icon.dart';
import 'package:crockbrowser/shared/widgets/feature_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('profile edits in place and saves the name', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('croc/native'),
      (call) async => null,
    );
    final store = BrowserStore(false);
    await tester.pumpWidget(
      MaterialApp(
        theme: CrockTheme.light,
        home: Scaffold(
          body: Column(
            children: [
              ProfileCard(store: store),
              const Text('Below profile'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your Browser'), findsOneWidget);
    final position = tester.getTopLeft(find.text('Below profile'));
    await tester.tap(find.text('Edit name'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Below profile')), position);
    await tester.enterText(find.byType(TextField), 'My phone');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('My phone'), findsOneWidget);
    expect(store.setting('profileName'), 'My phone');
    expect(tester.getTopLeft(find.text('Below profile')), position);
    await tester.tap(find.text('Edit name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Discard this');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('My phone'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await store.flush();
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('croc/native'),
      null,
    );
  });

  testWidgets('cached site icon renders on the first tab frame', (
    tester,
  ) async {
    await tester.runAsync(() => SiteIcons.load('https://google.com'));
    expect(SiteIcons.peek('https://google.com'), isNotNull);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SiteIcon(url: 'https://google.com', fallbackLabel: 'Google'),
        ),
      ),
    );
    // No extra pump: a newly mounted dashboard must not flash its fallback.
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('G'), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('modal keyboard leaves the covered page viewport unchanged', (
    tester,
  ) async {
    double? pageHeight;
    await tester.pumpWidget(
      MaterialApp(
        home: FeatureScaffold(
          title: 'Page',
          child: LayoutBuilder(
            builder: (context, constraints) {
              pageHeight = constraints.maxHeight;
              return Center(
                child: TextButton(
                  onPressed: () => showCrockDialog<void>(
                    context: context,
                    builder: (_) => const CrockDialog(
                      title: Text('Add shortcut'),
                      content: TextField(),
                    ),
                  ),
                  child: const Text('Open editor'),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    final height = pageHeight;
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    expect(pageHeight, height);
    final dialog = tester.widget<Dialog>(find.byType(Dialog));
    expect(dialog.insetAnimationDuration, Duration.zero);
    expect(tester.takeException(), isNull);
  });
}
