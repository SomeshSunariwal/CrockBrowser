import 'dart:async';

import 'package:crockbrowser/core/storage/browser_store.dart';
import 'package:crockbrowser/features/downloads/download_controller.dart';
import 'package:crockbrowser/features/downloads/youtube_quality_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final timeout in [false, true]) {
    testWidgets(
      'first quality request ${timeout ? 'times out with retry' : 'shows options'}',
      (tester) async {
        final messenger = tester.binding.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          const MethodChannel('croc/events'),
          (_) async => null,
        );
        final pending = Completer<Map<String, dynamic>>();
        messenger.setMockMethodCallHandler(const MethodChannel('croc/native'), (
          call,
        ) async {
          if (call.method == 'downloads.list') return [];
          if (call.method == 'youtube.formats') return pending.future;
          return null;
        });
        final downloads = DownloadController();
        final store = BrowserStore(true);
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showYouTubeQualityMenu(
                    context,
                    url: 'https://www.youtube.com/watch?v=jNQXAC9IVRw',
                    downloads: downloads,
                    store: store,
                    onView: () {},
                  ),
                  child: const Text('Download'),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('Download'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        if (timeout) {
          await tester.pump(const Duration(seconds: 30));
          await tester.pump();
          expect(find.text('Retry'), findsOneWidget);
          expect(find.textContaining('too long to respond'), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsNothing);
        } else {
          pending.complete({
            'title': 'Test video',
            'url': 'https://www.youtube.com/watch?v=jNQXAC9IVRw',
            'formats': [
              {
                'id': 'video:18',
                'label': '360p',
                'extension': 'mp4',
                'mime': 'video/mp4',
              },
            ],
          });
          await tester.pump();
          await tester.pump();
          expect(find.text('360p'), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsNothing);
        }
        await tester.pumpWidget(const SizedBox());
        downloads.dispose();
        store.dispose();
        await tester.pump();
      },
    );
  }
}
