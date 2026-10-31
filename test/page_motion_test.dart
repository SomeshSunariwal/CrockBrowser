import 'package:crockbrowser/core/theme/crock_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pages enter from the right and leave to the right', (
    tester,
  ) async {
    const pageKey = ValueKey('destination');
    late BuildContext pageContext;
    await tester.pumpWidget(
      MaterialApp(
        theme: CrockTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) {
                    pageContext = context;
                    return const Scaffold(key: pageKey, body: Text('Settings'));
                  },
                ),
              ),
              child: const Text('Open settings'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open settings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final entering = tester.getTopLeft(find.byKey(pageKey)).dx;
    expect(entering, greaterThan(0));
    expect(entering, lessThan(tester.view.physicalSize.width));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(pageKey)).dx, 0);
    Navigator.of(pageContext).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getTopLeft(find.byKey(pageKey)).dx, greaterThan(0));
    await tester.pumpAndSettle();
    expect(find.byKey(pageKey), findsNothing);
    expect(find.text('Open settings'), findsOneWidget);
  });
}
