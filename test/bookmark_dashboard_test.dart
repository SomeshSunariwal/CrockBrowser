import 'package:crockbrowser/core/storage/browser_store.dart';
import 'package:crockbrowser/core/theme/crock_theme.dart';
import 'package:crockbrowser/features/library/library_screen.dart';
import 'package:crockbrowser/shared/widgets/compact_list_row.dart';
import 'package:crockbrowser/shared/widgets/crock_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'bookmark menu adds to dashboard without duplicating or removing bookmark',
    (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('croc/native'),
        (call) async => null,
      );
      final store = BrowserStore(false);
      store.data['bookmarks'] = [
        {'id': 'saved', 'title': 'Google', 'url': 'https://google.com'},
      ];
      store.data['shortcuts'] = [
        {'id': 'first', 'title': 'Existing', 'url': 'https://example.com'},
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: CrockTheme.light,
          home: LibraryScreen(
            store: store,
            mode: 'bookmarks',
            onOpen: (_) {},
            onOffline: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> add() async {
        await tester.tap(
          find.descendant(
            of: find.byType(CompactListRow),
            matching: find.byType(CrockPopupMenuButton<String>),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Add to Dashboard'));
        await tester.pumpAndSettle();
      }

      await add();
      expect(store.readRows('shortcuts').first['id'], 'first');
      final shortcut = store.readRows('shortcuts').last;
      expect(shortcut['title'], 'Google');
      expect(shortcut['url'], 'https://google.com');
      expect(store.readRows('bookmarks').single['id'], 'saved');
      store.add('shortcuts', {
        'id': 'last',
        'title': 'Last',
        'url': 'https://example.org',
      }, prepend: false);
      await add();
      expect(store.readRows('shortcuts').map((row) => row['id']), [
        'first',
        shortcut['id'],
        'last',
      ]);
      expect(tester.takeException(), isNull);
      await store.flush();
      await tester.pumpWidget(const SizedBox());
      store.dispose();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('croc/native'),
        null,
      );
    },
  );
}
