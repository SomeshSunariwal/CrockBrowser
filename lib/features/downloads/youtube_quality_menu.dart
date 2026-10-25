import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/platform/native_bridge.dart';
import '../../core/storage/browser_store.dart';
import '../../core/theme/animation_timings.dart';
import '../../core/theme/app_motion.dart';
import '../../shared/widgets/feature_scaffold.dart';
import 'download_controller.dart';
import 'download_feedback.dart';

Future<void> showYouTubeQualityMenu(
  BuildContext context, {
  required String url,
  required DownloadController downloads,
  required BrowserStore store,
  required VoidCallback onView,
  Rect? anchor,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Dismiss video download',
  barrierColor: Colors.black26,
  transitionDuration: MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : AnimationTimings.downloadQualityPopup,
  transitionBuilder: (_, animation, _, child) => FadeTransition(
    opacity: animation.drive(CurveTween(curve: AppMotion.curve)),
    child: child,
  ),
  pageBuilder: (_, _, _) => _YouTubeQualityMenu(
    url: url,
    downloads: downloads,
    store: store,
    anchor: anchor,
    onAdded: (task) {
      if (!context.mounted) return;
      if (task != null) {
        showDownloadComplete(context, downloads, task);
      } else {
        crockMessage(
          context,
          'File added to downloads',
          actionLabel: 'View',
          onAction: () {
            if (context.mounted) onView();
          },
        );
      }
    },
  ),
);

class _YouTubeQualityMenu extends StatefulWidget {
  const _YouTubeQualityMenu({
    required this.url,
    required this.downloads,
    required this.store,
    required this.anchor,
    required this.onAdded,
  });
  final String url;
  final DownloadController downloads;
  final BrowserStore store;
  final Rect? anchor;
  final ValueChanged<Map<String, dynamic>?> onAdded;
  @override
  State<_YouTubeQualityMenu> createState() => _YouTubeQualityMenuState();
}

class _YouTubeQualityMenuState extends State<_YouTubeQualityMenu> {
  late Future<Map<String, dynamic>> request;
  String? starting, error;
  @override
  void initState() {
    super.initState();
    request = load();
  }

  Future<Map<String, dynamic>> load() async => Map<String, dynamic>.from(
    await NativeBridge.instance
            .call<Map>('youtube.formats', {'url': widget.url})
            .timeout(const Duration(seconds: 30)) ??
        {},
  );
  Future<void> start(
    Map<String, dynamic> video,
    Map<String, dynamic> format,
  ) async {
    if (starting != null) return;
    setState(() {
      starting = format['id'] as String;
      error = null;
    });
    final started = DateTime.now().millisecondsSinceEpoch;
    try {
      final title = String.fromCharCodes(
        (video['title'] as String? ?? 'YouTube video').runes.take(60),
      );
      await widget.downloads.add({
        'url': video['url'],
        'youtubeFormat': format['id'],
        'name': '$title (${format['label']}).${format['extension']}',
        'mime': format['mime'],
        'total': format['total'] ?? -1,
        'tree': widget.store.setting('downloadFolder', ''),
      });
      final completed = widget.downloads.tasks
          .where(
            (task) =>
                task['url'] == video['url'] &&
                task['state'] == 'complete' &&
                (task['created'] as num? ?? 0) >= started,
          )
          .firstOrNull;
      widget.onAdded(completed);
      if (mounted) dismissCrockRoute<void>(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          starting = null;
          error = 'Could not add this download. Please try again.';
        });
      }
    }
  }

  String failure(Object? failure) {
    final message = failure is PlatformException ? failure.message ?? '' : '';
    if (failure is TimeoutException ||
        message.toLowerCase().contains('timed out')) {
      return 'YouTube took too long to respond. Check your connection and retry.';
    }
    if (message.startsWith('Downloads currently') ||
        message.contains('rate-limiting') ||
        message.startsWith('No compatible')) {
      return message;
    }
    return 'Could not load download qualities for this video. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CustomSingleChildLayout(
      delegate: _QualityMenuPosition(
        widget.anchor,
        MediaQuery.paddingOf(context),
      ),
      child: Material(
        key: const ValueKey('youtube-quality-menu'),
        color: colors.surface,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: FutureBuilder<Map<String, dynamic>>(
          future: request,
          builder: (context, snapshot) {
            final data = snapshot.data;
            final formats = (data?['formats'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Text(
                    data?['title'] as String? ?? 'Download video',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (snapshot.connectionState != ConnectionState.done)
                  const Padding(
                    padding: EdgeInsets.all(28),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          semanticsLabel: 'Loading video qualities',
                        ),
                      ),
                    ),
                  )
                else if (snapshot.hasError || formats.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      children: [
                        Text(
                          failure(snapshot.error),
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            request = load();
                          }),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                else
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
                      children: [
                        for (final format in formats)
                          InkWell(
                            key: ValueKey('youtube-format-${format['id']}'),
                            borderRadius: BorderRadius.circular(12),
                            onTap: starting == null
                                ? () => start(data!, format)
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    format['extension'] == 'm4a'
                                        ? Icons.music_note_rounded
                                        : Icons.download_rounded,
                                    size: 20,
                                    color: colors.primary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      format['label'] as String,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                  if (starting == format['id'])
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  else
                                    Text(
                                      (format['extension'] as String)
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colors.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      error!,
                      style: TextStyle(fontSize: 12, color: colors.error),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _QualityMenuPosition extends SingleChildLayoutDelegate {
  _QualityMenuPosition(this.anchor, this.padding);
  final Rect? anchor;
  final EdgeInsets padding;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final width = math.min(300.0, constraints.maxWidth - 24);
    return BoxConstraints(
      minWidth: width,
      maxWidth: width,
      maxHeight: math.min(420, constraints.maxHeight - padding.vertical - 24),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = (anchor?.left ?? (size.width - childSize.width) / 2).clamp(
      12.0,
      math.max(12.0, size.width - childSize.width - 12),
    );
    final minTop = padding.top + 12;
    final maxTop = math.max(
      minTop,
      size.height - padding.bottom - childSize.height - 12,
    );
    var top = anchor == null
        ? (size.height - childSize.height) / 2
        : anchor!.bottom + 8;
    if (anchor != null && top > maxTop) {
      top = anchor!.top - childSize.height - 8;
    }
    return Offset(left.toDouble(), top.clamp(minTop, maxTop).toDouble());
  }

  @override
  bool shouldRelayout(_QualityMenuPosition oldDelegate) =>
      oldDelegate.anchor != anchor || oldDelegate.padding != padding;
}
