import 'package:flutter/material.dart';

import '../../core/storage/browser_store.dart';
import '../../shared/widgets/crock_logo.dart';
import '../../shared/widgets/feature_scaffold.dart';
import 'download_controller.dart';
import 'download_feedback.dart';
import 'downloads_screen.dart';

Future<void> showDownloadSheet(
  BuildContext context,
  DownloadController downloads,
  BrowserStore store, [
  Map<String, dynamic> draft = const {},
]) async {
  final navigator = Navigator.of(context);
  await showCrockSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _DownloadSheet(
      downloads: downloads,
      store: store,
      draft: draft,
      onComplete: (task) {
        final target = navigator.overlay?.context;
        if (target != null && target.mounted) {
          showDownloadComplete(target, downloads, task);
        }
      },
      onView: () {
        if (!navigator.mounted) return;
        if (context.mounted &&
            (context.widget is DownloadsScreen ||
                context.findAncestorWidgetOfExactType<DownloadsScreen>() !=
                    null)) {
          return;
        }
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => DownloadsScreen(downloads: downloads, store: store),
          ),
        );
      },
    ),
  );
}

class _DownloadSheet extends StatefulWidget {
  const _DownloadSheet({
    required this.downloads,
    required this.store,
    required this.draft,
    required this.onView,
    required this.onComplete,
  });
  final DownloadController downloads;
  final BrowserStore store;
  final Map<String, dynamic> draft;
  final VoidCallback onView;
  final ValueChanged<Map<String, dynamic>> onComplete;
  @override
  State<_DownloadSheet> createState() => _DownloadSheetState();
}

class _DownloadSheetState extends State<_DownloadSheet> {
  late final url = TextEditingController(
    text: widget.draft['url'] as String? ?? '',
  );
  late final filename = TextEditingController(
    text: widget.draft['name'] as String? ?? '',
  );
  bool busy = false;
  @override
  void dispose() {
    url.dispose();
    filename.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      0,
      24,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              CrockLogo(size: 38),
              SizedBox(width: 8),
              Text(
                'New download',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Download URL',
              hintText: 'HTTPS file, media playlist or magnet link',
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: filename,
            decoration: const InputDecoration(
              labelText: 'Filename',
              hintText: 'Leave blank to use the URL filename',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.folder_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.store.setting('downloadFolder', '').toString().isEmpty
                      ? 'Crock downloads · app storage'
                      : 'Selected download folder + local copy',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF75828F),
                  ),
                ),
              ),
            ],
          ),
          if ((widget.draft['total'] as num? ?? -1) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(byteLabel(widget.draft['total'] as num)),
            ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() => busy = true);
                      final started = DateTime.now().millisecondsSinceEpoch;
                      try {
                        final uri = Uri.tryParse(url.text.trim());
                        final path = uri?.pathSegments
                            .where((p) => p.isNotEmpty)
                            .lastOrNull;
                        await widget.downloads.add({
                          ...widget.draft,
                          'url': url.text.trim(),
                          'name': filename.text.trim().isEmpty
                              ? (uri?.scheme == 'magnet'
                                    ? (uri?.queryParameters['dn'] ?? 'Torrent')
                                    : (path ?? 'download'))
                              : filename.text.trim(),
                          'tree': widget.store.setting('downloadFolder', ''),
                        });
                        if (context.mounted) {
                          // A tiny file can finish before the sheet closes.
                          // Keep its Open action instead of replacing it with View.
                          final finished = widget.downloads.tasks
                              .where(
                                (task) =>
                                    task['url'] == url.text.trim() &&
                                    task['state'] == 'complete' &&
                                    (task['created'] as num? ?? 0) >= started,
                              )
                              .firstOrNull;
                          if (finished != null) {
                            widget.onComplete(finished);
                          } else {
                            crockMessage(
                              context,
                              'File added to downloads',
                              actionLabel: 'View',
                              onAction: widget.onView,
                            );
                          }
                          dismissCrockRoute<void>(context);
                        }
                      } catch (error) {
                        if (context.mounted) {
                          setState(() => busy = false);
                          crockMessage(context, error);
                        }
                      }
                    },
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(busy ? 'Adding to queue…' : 'Start download'),
            ),
          ),
        ],
      ),
    ),
  );
}
