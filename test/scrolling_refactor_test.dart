import 'dart:async';

import 'package:crockbrowser/core/storage/browser_store.dart';
import 'package:crockbrowser/core/theme/crock_theme.dart';
import 'package:crockbrowser/features/files/files_screen.dart';
import 'package:crockbrowser/features/library/library_screen.dart';
import 'package:crockbrowser/shared/widgets/compact_list_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final mode in ['history', 'bookmarks']) {
    testWidgets('$mode keeps a 5000-item list lazy across many dates', (
      tester,
    ) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('croc/native'),
        (call) async => null,
      );
      final store = BrowserStore(false);
      final now = DateTime.now();
      store.data[mode] = List.generate(
        5000,
        (index) => {
          'id': '$index',
          'title': 'Item $index',
          'url': 'https://google.com/?q=$index',
          'created': now.subtract(Duration(days: index)).millisecondsSinceEpoch,
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: CrockTheme.light,
          home: LibraryScreen(
            store: store,
            mode: mode,
            onOpen: (_) {},
            onOffline: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CompactListRow).evaluate().length, lessThan(30));
      expect(find.text('Item 4999'), findsNothing);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1600));
      await tester.pumpAndSettle();
      expect(find.byType(CompactListRow).evaluate().length, lessThan(30));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      store.dispose();
    });
  }

  testWidgets('file refresh ignores stale results and keeps large lists lazy', (
    tester,
  ) async {
    final old = Completer<List<Map<String, dynamic>>>();
    final latest = Completer<List<Map<String, dynamic>>>();
    var requests = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('croc/native'),
      (call) async => call.method == 'files.list'
          ? (++requests == 1 ? old.future : latest.future)
          : null,
    );
    await tester.pumpWidget(
      MaterialApp(theme: CrockTheme.light, home: const FilesScreen()),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pump();
    latest.complete(
      List.generate(
        2000,
        (i) => {
          'name': 'New $i',
          'path': '/new/$i',
          'mime': 'text/plain',
          'size': 1,
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('New 0'), findsOneWidget);
    expect(find.byType(ListTile).evaluate().length, lessThan(30));
    old.complete([
      {'name': 'Stale file', 'path': '/old', 'mime': 'text/plain'},
    ]);
    await tester.pumpAndSettle();
    expect(find.text('New 0'), findsOneWidget);
    expect(find.text('Stale file'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
