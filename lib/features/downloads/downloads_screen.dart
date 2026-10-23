import 'package:flutter/material.dart';

import '../../core/platform/native_bridge.dart';
import '../../core/storage/browser_store.dart';
import '../../shared/widgets/crock_logo.dart';
import '../../shared/widgets/feature_scaffold.dart';
import 'download_controller.dart';
import 'download_sheet.dart';
import '../files/files_screen.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({
    super.key,
    required this.downloads,
    required this.store,
  });
  final DownloadController downloads;
  final BrowserStore store;
  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  String filter = 'all';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.downloads,
    builder: (context, _) {
      final tasks = widget.downloads.tasks
          .where(
            (task) =>
                filter == 'all' ||
                (filter == 'active' &&
                    [
                      'queued',
                      'running',
                      'retrying',
                      'paused',
                    ].contains(task['state'])) ||
                (filter == 'complete' && task['state'] == 'complete') ||
                (filter == 'failed' &&
                    ['failed', 'cancelled'].contains(task['state'])),
          )
          .toList();
      final active = widget.downloads.tasks
          .where((t) => t['state'] == 'running')
          .length;
      return FeatureScaffold(
        title: 'Downloads',
        actions: [
          IconButton(
            tooltip: 'New download',
            onPressed: () =>
                showDownloadSheet(context, widget.downloads, widget.store),
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: 'Download options',
            onPressed: _options,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  colors: [Color(0xFF087CFA), Color(0xFF21BBDD)],
                ),
              ),
              child: Row(
                children: [
                  const CrockLogo(size: 48),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$active active transfers',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Your files. Your pace.',
                          style: TextStyle(
                            color: Color(0xFFDFF4FF),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => widget.downloads.refresh(),
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  for (final item in [
                    ('all', 'All'),
                    ('active', 'In progress'),
                    ('complete', 'Completed'),
                    ('failed', 'Failed'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(item.$2),
                        selected: filter == item.$1,
                        onSelected: (_) => setState(() => filter = item.$1),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.downloads.lastError != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  widget.downloads.lastError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Expanded(
              child: tasks.isEmpty
                  ? CrockEmpty(
                      title: widget.downloads.loading
                          ? 'Loading downloads…'
                          : 'Your next download goes here',
                      detail: 'Download links from the browser or add a direct file URL. Pause, resume and retry from this screen.',
                      action: FilledButton.icon(
                        onPressed: () => showDownloadSheet(
                          context,
                          widget.downloads,
                          widget.store,
                        ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add download'),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: widget.downloads.refresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        itemCount: tasks.length,
                        itemBuilder: (context, index) => _task(tasks[index]),
                      ),
                    ),
            ),
          ],
        ),
      );
    },
  );
  Widget _task(Map<String, dynamic> task) {
    final state = task['state'] as String;
    final bytes = (task['bytes'] as num? ?? 0),
        total = (task['total'] as num? ?? -1);
    final running = state == 'running', complete = state == 'complete';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3FF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    complete
                        ? Icons.check_circle_outline_rounded
                        : Icons.insert_drive_file_outlined,
                    color: const Color(0xFF087CFA),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task['name'] as String,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        Uri.tryParse(task['url'] as String)?.host ?? '',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF8796A6),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) => _action(task, action),
                  itemBuilder: (context) => [
                    if (complete)
                      const PopupMenuItem(
                        value: 'open',
                        child: Text('Open file'),
                      ),
                    if (complete &&
                        task['stream'] != true &&
                        task['torrent'] != true)
                      const PopupMenuItem(
                        value: 'share',
                        child: Text('Share file'),
                      ),
                    if (complete &&
                        task['stream'] != true &&
                        task['torrent'] != true)
                      const PopupMenuItem(
                        value: 'export',
                        child: Text('Save a copy…'),
                      ),
                    if (!complete)
                      const PopupMenuItem(
                        value: 'cancel',
                        child: Text('Cancel download'),
                      ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Text('Remove download and local file'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 15),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 5,
                value: total > 0
                    ? (bytes / total).clamp(0, 1)
                    : running
                    ? null
                    : 0,
                backgroundColor: const Color(0xFFEEF2F7),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${byteLabel(bytes)}${total > 0 ? ' / ${byteLabel(total)}' : ''}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF75828F),
                    ),
                  ),
                ),
                Text(
                  running
                      ? '${byteLabel(task['speed'] as num? ?? 0)}/s'
                      : state[0].toUpperCase() + state.substring(1),
                  style: TextStyle(
                    fontSize: 11,
                    color: complete
                        ? const Color(0xFF04A58E)
                        : const Color(0xFF087CFA),
                  ),
                ),
                if (!complete)
                  IconButton(
                    tooltip: running || state == 'queued' || state == 'retrying'
                        ? 'Pause'
                        : 'Resume',
                    onPressed: () => _action(
                      task,
                      running || state == 'queued' || state == 'retrying'
                          ? 'pause'
                          : 'resume',
                    ),
                    icon: Icon(
                      running || state == 'queued' || state == 'retrying'
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                    ),
                  ),
              ],
            ),
            if ((task['error'] as String? ?? '').isNotEmpty)
              Text(
                task['error'] as String,
                style: const TextStyle(fontSize: 11, color: Color(0xFFC16843)),
              ),
            if (complete)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _action(task, 'open'),
                  child: const Text('Open file'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _action(Map<String, dynamic> task, String action) async {
    try {
      if (['cancel', 'remove'].contains(action) &&
          !await confirmCrock(
            context,
            '${action == 'remove' ? 'Remove' : 'Cancel'} download?',
            action == 'remove'
                ? 'The app-managed file will also be removed. Exported copies are kept.'
                : 'The incomplete file will be removed.',
          )) {
        return;
      }
      if (['open', 'share', 'export'].contains(action)) {
        final file = await widget.downloads.file(task['id'] as String);
        if (file['exists'] != true) {
          throw StateError('The local file has been moved or removed');
        }
        if (file['stream'] == true) {
          if (action != 'open') {
            throw StateError(
              'Adaptive media is stored as segments for offline playback in Crock Player.',
            );
          }
          await NativeBridge.instance.call('media.play', {
            'uri': file['url'],
            'downloadId': task['id'],
          });
          return;
        }
        if (file['torrent'] == true) {
          if (action != 'open') {
            throw StateError(
              'Open the torrent folder to share or export individual files.',
            );
          }
          if (mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) =>
                    FilesScreen(initialPath: file['path'] as String),
              ),
            );
          }
          return;
        }
        final mime = file['mime'] as String? ?? '';
        if (action == 'open' &&
            (mime.startsWith('video/') || mime.startsWith('audio/'))) {
          await NativeBridge.instance.call('media.play', {
            'path': file['path'],
          });
        } else {
          await NativeBridge.instance.call('files.$action', {
            'path': file['path'],
            'name': file['name'],
            'mime': file['mime'],
          });
        }
      } else {
        await widget.downloads.command(task['id'] as String, action);
      }
    } catch (error) {
      if (mounted) crockMessage(context, error);
    }
  }

  Future<void> _options() async {
    final options = Map<String, dynamic>.from(
      await NativeBridge.instance.call<Map>('downloads.settings') ?? {},
    );
    if (!mounted) return;
    int concurrency = options['concurrency'] as int? ?? 3;
    bool wifi = options['wifiOnly'] == true;
    await showCrockSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Download options',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 20),
              Text('$concurrency simultaneous downloads'),
              Slider(
                min: 1,
                max: 6,
                divisions: 5,
                value: concurrency.toDouble(),
                onChanged: (value) =>
                    setLocal(() => concurrency = value.round()),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Unmetered networks only'),
                subtitle: const Text(
                  'Queued downloads wait for Wi-Fi or another unmetered connection.',
                ),
                value: wifi,
                onChanged: (value) => setLocal(() => wifi = value),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.folder_outlined),
                title: const Text('Choose destination folder'),
                subtitle: Text(
                  widget.store.setting('downloadFolder', '').toString().isEmpty
                      ? 'App-managed downloads'
                      : 'A folder is selected',
                ),
                onTap: () async {
                  try {
                    final folder = await NativeBridge.instance.call<String>(
                      'files.pickFolder',
                    );
                    if (folder != null) {
                      widget.store.setSetting('downloadFolder', folder);
                      setLocal(() {});
                    }
                  } catch (error) {
                    if (context.mounted) crockMessage(context, error);
                  }
                },
              ),
              if (widget.store
                  .setting('downloadFolder', '')
                  .toString()
                  .isNotEmpty)
                TextButton(
                  onPressed: () => setLocal(
                    () => widget.store.setSetting('downloadFolder', ''),
                  ),
                  child: const Text('Use app-managed folder only'),
                ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await NativeBridge.instance.call('downloads.settings', {
                      'concurrency': concurrency,
                      'wifiOnly': wifi,
                    });
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save options'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
