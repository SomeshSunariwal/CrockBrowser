import 'package:crockbrowser/core/storage/browser_store.dart';
import 'package:crockbrowser/core/theme/crock_theme.dart';
import 'package:crockbrowser/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('dashboard search releases touch focus, dark=$dark', (
      tester,
    ) async {
      final store = BrowserStore(false);
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? CrockTheme.dark : CrockTheme.light,
          home: Scaffold(
            body: HomeScreen(
              store: store,
              onSearch: (_) {},
              onTool: (_) {},
              onShortcut: (_) {},
              onEditShortcut: (_) {},
              privateMode: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.focusNode.hasFocus, isTrue);
      await tester.enterText(find.byType(TextField), 'keep this query');
      await tester.tap(find.text('Crock Browser'));
      await tester.pumpAndSettle();
      expect(editable.focusNode.hasFocus, isFalse);
      expect(find.text('keep this query'), findsOneWidget);
      final decoration = tester
          .widget<TextField>(find.byType(TextField))
          .decoration!;
      expect(decoration.enabledBorder!.borderSide.width, 1);
      expect(decoration.enabledBorder!.borderSide.style, BorderStyle.solid);
      expect(decoration.enabledBorder!.borderSide.color.a, greaterThan(.5));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  }
}
