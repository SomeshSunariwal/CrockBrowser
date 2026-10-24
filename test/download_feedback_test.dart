import 'package:crockbrowser/core/storage/browser_store.dart';
import 'package:crockbrowser/features/downloads/download_controller.dart';
import 'package:crockbrowser/features/downloads/downloads_screen.dart';
import 'package:crockbrowser/shared/widgets/crock_notification.dart';
import 'package:crockbrowser/shared/widgets/feature_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'download graph survives repeated 100 ms samples and speed changes',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        const MethodChannel('croc/events'),
        (_) async => null,
      );
      messenger.setMockMethodCallHandler(const MethodChannel('croc/native'), (
        call,
      ) async {
        if (call.method == 'downloads.list') return <Object>[];
        return null;
      });
      final controller = DownloadController();
      await tester.pump();
      controller.tasks = [
        {
          'id': 'test-download',
          'name': 'example.bin',
          'url': 'https://example.test/file',
          'state': 'running',
          'bytes': 1024,
          'total': 8192,
          'speed': 2048,
          'speedHistory': [
            [0.0, 0.0],
            [0.05, 2048.0],
            [0.125, 1024.0],
          ],
        },
      ];
      controller.lastError = '';
      await tester.pumpWidget(
        MaterialApp(
          home: DownloadsScreen(
            downloads: controller,
            store: BrowserStore(false),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      }
      final filtersBottom = tester
          .getBottomLeft(find.byType(SingleChildScrollView).first)
          .dy;
      final sectionTop = tester.getTopLeft(find.text('In progress').last).dy;
      expect(sectionTop - filtersBottom, lessThanOrEqualTo(28));
      final card = find
          .ancestor(of: find.text('example.bin'), matching: find.byType(Card))
          .first;
      final cardRect = tester.getRect(card);
      final dividerRect = tester.getRect(
        find.descendant(of: card, matching: find.byType(Divider)),
      );
      final initialChart = find.descendant(
        of: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.label?.startsWith('Download progress ') ??
                  false),
        ),
        matching: find.byType(CustomPaint),
      );
      final graphRect = tester.getRect(initialChart);
      expect(graphRect.width, cardRect.width - 24);
      expect(graphRect.left, cardRect.left + 12);
      expect(graphRect.right, cardRect.right - 12);
      final pauseButton = tester.widget<IconButton>(
        find.byWidgetPredicate(
          (widget) => widget is IconButton && widget.tooltip == 'Pause',
        ),
      );
      expect(
        pauseButton.style?.backgroundColor?.resolve({}),
        Colors.transparent,
      );
      expect(graphRect.height, dividerRect.top - cardRect.top);
      expect(
        graphRect.contains(tester.getCenter(find.byTooltip('Pause'))),
        isTrue,
      );
      controller.tasks.first['speed'] = 4096;
      controller.tasks.first['bytes'] = 4096;
      controller.tasks.first['speedHistory'] = [
        [0.0, 0.0],
        [0.05, 2048.0],
        [0.125, 1024.0],
        [0.5, 4096.0],
      ];
      controller.notifyListeners();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('4.0 KB/s'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Download progress 50 percent',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      // Native snapshots continue updating while the download page is absent.
      controller.tasks.first['state'] = 'paused';
      controller.tasks.first['speed'] = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: DownloadsScreen(
            downloads: controller,
            store: BrowserStore(false),
          ),
        ),
      );
      await tester.pump();
      final chart = find.descendant(
        of: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label == 'Download progress 50 percent',
        ),
        matching: find.byType(CustomPaint),
      );
      final dynamic painter = tester.widget<CustomPaint>(chart).painter;
      expect(painter.samples, const [
        Offset(0, 0),
        Offset(.05, 2048),
        Offset(.125, 1024),
        Offset(.5, 4096),
      ]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets('download graph colors and cancelled retry follow task state', (
    tester,
  ) async {
    final commands = <Map>[];
    final row = <String, dynamic>{
      'id': 'color-download',
      'name': 'example.bin',
      'url': 'https://example.test/file',
      'state': 'running',
      'bytes': 4096,
      'total': 8192,
      'speed': 1024,
      'speedHistory': [
        [0.0, 0.0],
        [0.5, 1024.0],
      ],
    };
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('croc/events'),
      (_) async => null,
    );
    messenger.setMockMethodCallHandler(const MethodChannel('croc/native'), (
      call,
    ) async {
      if (call.method == 'downloads.list') return [row];
      if (call.method == 'downloads.command') {
        commands.add(call.arguments as Map);
      }
      return null;
    });
    final controller = DownloadController();
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: DownloadsScreen(
          downloads: controller,
          store: BrowserStore(false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final entry in <String, Color>{
      'running': ThemeData().colorScheme.primary,
      'complete': const Color(0xFF16A34A),
      'cancelled': const Color(0xFFFBC02D),
      'failed': const Color(0xFFDC2626),
    }.entries) {
      row['state'] = entry.key;
      controller.tasks = [Map<String, dynamic>.from(row)];
      controller.notifyListeners();
      await tester.pump();
      final label = entry.key == 'complete'
          ? 'Completed'
          : entry.key == 'running'
          ? 'In progress'
          : 'Failed';
      await tester.tap(find.widgetWithText(ChoiceChip, label));
      await tester.pumpAndSettle();
      final chart = find.descendant(
        of: find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              (widget.properties.label?.startsWith('Download progress ') ??
                  false),
        ),
        matching: find.byType(CustomPaint),
      );
      final dynamic painter = tester.widget<CustomPaint>(chart).painter;
      expect(painter.color, entry.value, reason: entry.key);
      if (entry.key == 'cancelled') {
        await tester.tap(find.byTooltip('Retry download'));
        await tester.pumpAndSettle(const Duration(milliseconds: 250));
        expect(commands.last, {'id': 'color-download', 'action': 'retry'});
        await tester.tap(find.byIcon(Icons.more_vert_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Retry download'), findsOneWidget);
        expect(find.text('Cancel download'), findsNothing);
        await tester.tap(find.text('Retry download'));
        await tester.pumpAndSettle(const Duration(milliseconds: 250));
        expect(commands.length, 2);
      }
    }
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets(
    'shared banner renders, closes, and dismisses after four seconds',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (_, child) => CrockNotificationHost(child: child!),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    crockMessage(context, 'File added to downloads'),
                child: const Text('Start'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(find.text('File added to downloads'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('File added to downloads'), findsNothing);
      await tester.tap(find.text('Start'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.text('File added to downloads'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
