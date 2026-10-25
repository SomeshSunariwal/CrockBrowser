import 'package:flutter/material.dart';

import '../../core/platform/native_bridge.dart';
import '../../shared/widgets/feature_scaffold.dart';
import '../files/files_screen.dart';
import 'download_controller.dart';

void showDownloadComplete(
  BuildContext context,
  DownloadController downloads,
  Map<String, dynamic> task,
) {
  crockMessage(
    context,
    'Download complete',
    actionLabel: 'Open',
    onAction: () {
      if (context.mounted) {
        openCompletedDownload(context, downloads, task['id'] as String);
      }
    },
  );
}

Future<void> openCompletedDownload(
  BuildContext context,
  DownloadController downloads,
  String id,
) async {
  try {
    final file = await downloads.file(id);
    if (!context.mounted) return;
    if (file['exists'] != true) {
      throw StateError('The local file has been moved or removed');
    }
    if (file['stream'] == true) {
      await NativeBridge.instance.call('media.play', {
        'uri': file['url'],
        'downloadId': id,
      });
    } else if (file['torrent'] == true) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FilesScreen(initialPath: file['path'] as String),
        ),
      );
    } else {
      final mime = file['mime'] as String? ?? '';
      await NativeBridge.instance.call(
        mime.startsWith('video/') || mime.startsWith('audio/')
            ? 'media.play'
            : 'files.open',
        {'path': file['path'], 'name': file['name'], 'mime': file['mime']},
      );
    }
  } catch (error) {
    if (context.mounted) crockMessage(context, error);
  }
}
