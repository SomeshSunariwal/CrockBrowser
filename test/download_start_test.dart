import 'dart:async';
import 'dart:convert';

import 'package:crockbrowser/features/downloads/download_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final withSnapshot in [true, false]) {
    testWidgets(
      'queue starts before permission resolves (snapshot=$withSnapshot)',
      (tester) async {
        final messenger = tester.binding.defaultBinaryMessenger;
        const codec = StandardMethodCodec();
        messenger.setMockMethodCallHandler(
          const MethodChannel('croc/events'),
          (_) async => null,
        );
        final permission = Completer<bool>();
        var lists = 0;
        String? requestId;
        final rows = [
          {
            'id': 'test-file',
            'url': 'https://example.com/file.zip',
            'state': 'queued',
          },
        ];
        messenger.setMockMethodCallHandler(const MethodChannel('croc/native'), (
          call,
        ) async {
          switch (call.method) {
            case 'downloads.list':
              lists++;
              return lists == 1 ? [] : rows;
            case 'device.permissions':
              return permission.future;
            case 'downloads.enqueue':
              requestId = (call.arguments as Map)['requestId'] as String;
              return true;
          }
          return null;
        });
        final downloads = DownloadController();
        await tester.pump();
        final queued = downloads.add({'url': 'https://example.com/file.zip'});
        await tester.pump();
        expect(requestId, isNotNull);
        expect(permission.isCompleted, isFalse);
        await messenger.handlePlatformMessage(
          'croc/events',
          codec.encodeSuccessEnvelope({
            'type': 'downloads',
            'requestId': requestId,
            'error': '',
            if (withSnapshot) 'tasksJson': jsonEncode(rows),
          }),
          (_) {},
        );
        await tester.pump();
        await queued;
        expect(downloads.tasks.single['id'], 'test-file');
        expect(lists, withSnapshot ? 1 : 2);
        permission.complete(false);
        await tester.pump();
        downloads.dispose();
        await tester.pump();
      },
    );
  }
}
