import 'package:flutter/material.dart';

import '../../core/storage/browser_store.dart';
import '../../shared/widgets/crock_logo.dart';
import '../../shared/widgets/feature_scaffold.dart';
import 'download_controller.dart';

Future<void> showDownloadSheet(
  BuildContext context,
  DownloadController downloads,
  BrowserStore store, [
  Map<String, dynamic> draft = const {},
]) async {
  await showCrockSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) =>
        _DownloadSheet(downloads: downloads, store: store, draft: draft),
  );
}

class _DownloadSheet extends StatefulWidget {
  const _DownloadSheet({
    required this.downloads,
    required this.store,
    required this.draft,
  });
  final DownloadController downloads;
  final BrowserStore store;
  final Map<String, dynamic> draft;
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
              SizedBox(width: 12),
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
              const SizedBox(width: 10),
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
                          crockMessage(context, 'File added to downloads');
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
