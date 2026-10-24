import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;

import '../../core/platform/native_bridge.dart';
import '../../core/storage/browser_store.dart';
import '../../shared/widgets/crock_logo.dart';
import '../../shared/widgets/feature_scaffold.dart';
import 'download_controller.dart';
import 'download_feedback.dart';
import 'download_sheet.dart';
import '../files/files_screen.dart';
import '../files/archive_actions.dart';

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
  bool _inProgressExpanded = true;
  bool _completedExpanded = false;
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
      const activeStates = {'queued', 'running', 'retrying', 'paused'};
      final inProgressTasks = tasks
          .where((task) => activeStates.contains(task['state']))
          .toList();
      final completedTasks = tasks
          .where((task) => !activeStates.contains(task['state']))
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
            if (widget.downloads.lastError?.trim().isNotEmpty == true)
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
                      child: filter == 'all'
                          ? ListView(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                32,
                              ),
                              children: [
                                _sectionHeader(
                                  title: 'In progress',
                                  count: inProgressTasks.length,
                                  expanded: _inProgressExpanded,
                                  onTap: () => setState(() {
                                    _inProgressExpanded = !_inProgressExpanded;
                                  }),
                                ),
                                if (_inProgressExpanded)
                                  ...inProgressTasks.map(_task),
                                _sectionHeader(
                                  title: 'Completed',
                                  count: completedTasks.length,
                                  expanded: _completedExpanded,
                                  onTap: () => setState(() {
                                    _completedExpanded = !_completedExpanded;
                                  }),
                                ),
                                if (_completedExpanded)
                                  ...completedTasks.map(_task),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                32,
                              ),
                              itemCount: tasks.length,
                              itemBuilder: (context, index) =>
                                  _task(tasks[index]),
                            ),
                    ),
            ),
          ],
        ),
      );
    },
  );

  Widget _sectionHeader({
    required String title,
    required int count,
    required bool expanded,
    required VoidCallback onTap,
  }) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 12),
          Icon(
            expanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    ),
  );

  Widget _task(Map<String, dynamic> task) {
    final state = task['state'] as String;
    final bytes = (task['bytes'] as num? ?? 0),
        total = (task['total'] as num? ?? -1);
    final running = state == 'running', complete = state == 'complete';
    final canRetry =
        state == 'cancelled' || state == 'failed' || state == 'error';
    final canPause = running || state == 'queued' || state == 'retrying';
    final textScaler = MediaQuery.textScalerOf(context);
    final sectionHeight =
        (textScaler.scale(13) * 1.5 + textScaler.scale(11) * 1.5 + 27).clamp(
          64.0,
          double.infinity,
        );
    final graphColor = switch (state) {
      'complete' => const Color(0xFF16A34A),
      'cancelled' => const Color(0xFFFBC02D),
      'failed' || 'error' => const Color(0xFFDC2626),
      _ => Theme.of(context).colorScheme.primary,
    };
    return Card(
      key: ValueKey('download-${task['id']}'),
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: sectionHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      complete
                          ? Icons.check_circle_outline_rounded
                          : Icons.insert_drive_file_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task['name']?.toString() ?? 'Download',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            Uri.tryParse(task['url']?.toString() ?? '')?.host ??
                                '',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                      onSelected: (action) => _action(task, action),
                      itemBuilder: (context) => [
                        if (complete &&
                            task['stream'] != true &&
                            task['torrent'] != true &&
                            isSupportedArchive(task['name'].toString()))
                          const PopupMenuItem(
                            value: 'extract',
                            child: Text('Extract archive'),
                          ),
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
                        if (canRetry)
                          const PopupMenuItem(
                            value: 'retry',
                            child: Text('Retry download'),
                          ),
                        if (!complete && !canRetry)
                          const PopupMenuItem(
                            value: 'cancel',
                            child: Text('Cancel download'),
                          ),
                        const PopupMenuItem(
                          value: 'remove',
                          child: Text('Remove download and local file'),
                        ),
                      ],
                      icon: const Icon(Icons.more_vert_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            indent: 12,
            endIndent: 12,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          SizedBox(
            height: sectionHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _DownloadSpeedGraph(
                    key: ValueKey(task['id']),
                    history: (task['speedHistory'] as List? ?? const []).map((
                      sample,
                    ) {
                      final point = sample as List;
                      return Offset(
                        (point[0] as num).toDouble(),
                        (point[1] as num).toDouble(),
                      );
                    }).toList(),
                    progress: complete
                        ? 1
                        : (total > 0
                              ? (bytes / total).clamp(0.0, 1.0).toDouble()
                              : 0),
                    color: graphColor,
                  ),
                ),
                if (!complete)
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                        tooltip: canRetry
                            ? 'Retry download'
                            : canPause
                            ? 'Pause'
                            : 'Resume',
                        onPressed: () => _action(
                          task,
                          canRetry
                              ? 'retry'
                              : canPause
                              ? 'pause'
                              : 'resume',
                        ),
                        icon: Icon(
                          canRetry
                              ? Icons.refresh_rounded
                              : canPause
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 8,
                  left: 72,
                  right: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${byteLabel(bytes)}${total > 0 ? ' / ${byteLabel(total)}' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        running
                            ? '${byteLabel(task['speed'] as num? ?? 0)}/s'
                            : state[0].toUpperCase() + state.substring(1),
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: graphColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if ((task['error'] as String? ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  task['error'] as String,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _action(Map<String, dynamic> task, String action) async {
    if (action == 'open') {
      await openCompletedDownload(
        context,
        widget.downloads,
        task['id'] as String,
      );
      return;
    }
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
      if (['share', 'export', 'extract'].contains(action)) {
        final file = await widget.downloads.file(task['id'] as String);
        if (file['exists'] != true) {
          throw StateError('The local file has been moved or removed');
        }
        if (action == 'extract') {
          if (!mounted) return;
          final folder = await extractArchive(context, file);
          if (folder != null && mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => FilesScreen(initialPath: folder),
              ),
            );
          }
          return;
        }
        if (file['stream'] == true) {
          throw StateError(
            'Adaptive media is stored as segments for offline playback in Crock Player.',
          );
        }
        if (file['torrent'] == true) {
          throw StateError(
            'Open the torrent folder to share or export individual files.',
          );
        }
        await NativeBridge.instance.call('files.$action', {
          'path': file['path'],
          'name': file['name'],
          'mime': file['mime'],
        });
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

class _DownloadSpeedGraph extends StatelessWidget {
  const _DownloadSpeedGraph({
    super.key,
    required this.color,
    required this.history,
    required this.progress,
  });

  final Color color;
  final List<Offset> history;
  final double progress;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Download progress ${(progress * 100).round()} percent',
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: ClipRect(
          child: CustomPaint(
            painter: _DownloadSpeedPainter(
              history.isEmpty ? [Offset.zero, Offset(progress, 0)] : history,
              color,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  );
}

class _DownloadSpeedPainter extends CustomPainter {
  const _DownloadSpeedPainter(this.samples, this.color);

  final List<Offset> samples;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty || size.isEmpty) return;

    final peak = samples.fold<double>(
      1,
      (maximum, value) => value.dy > maximum ? value.dy : maximum,
    );
    final top = size.height * .40;
    final bottom = size.height * .80;
    final points = <Offset>[];
    for (var index = 0; index < samples.length; index++) {
      final x = size.width * samples[index].dx;
      final normalized = (samples[index].dy / peak).clamp(0.0, 1.0);
      final y = bottom - normalized * (bottom - top);
      points.add(Offset(x, y));
    }

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      final segment = current.dx - previous.dx;
      final before = points[index - 2 < 0 ? 0 : index - 2];
      final after = points[index + 1 < points.length ? index + 1 : index];
      final previousControlY = (previous.dy + (current.dy - before.dy) / 6)
          .clamp(top, bottom)
          .toDouble();
      final currentControlY = (current.dy - (after.dy - previous.dy) / 6)
          .clamp(top, bottom)
          .toDouble();
      line.cubicTo(
        previous.dx + segment / 3,
        previousControlY,
        current.dx - segment / 3,
        currentControlY,
        current.dx,
        current.dy,
      );
    }

    final area = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: .18), color.withValues(alpha: 0)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(area, fill);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(line, stroke);
  }

  @override
  bool shouldRepaint(covariant _DownloadSpeedPainter oldDelegate) =>
      oldDelegate.color != color || !listEquals(oldDelegate.samples, samples);
}
