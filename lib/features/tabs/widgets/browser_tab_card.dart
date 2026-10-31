import 'package:flutter/material.dart';

import '../../../core/models/browser_tab.dart';
import '../../../core/theme/crock_theme.dart';
import '../../../shared/widgets/crock_logo.dart';
import 'tab_window_transition.dart';

class BrowserTabCard extends StatelessWidget {
  const BrowserTabCard({
    super.key,
    required this.tab,
    required this.selected,
    required this.grid,
    required this.onSelect,
    required this.onClose,
    this.previewHero = false,
    this.showClose = true,
  });
  final BrowserTab tab;
  final bool selected, grid;
  final bool previewHero, showClose;
  final VoidCallback onSelect, onClose;

  String get title => tab.atHome ? 'Home' : tab.title;
  String get host => tab.atHome
      ? 'Start something new'
      : Uri.tryParse(tab.url)?.host ?? tab.url;

  Widget _close({bool overlay = false}) => IconButton(
    tooltip: 'Close $title tab',
    onPressed: onClose,
    padding: EdgeInsets.zero,
    constraints: BoxConstraints.tightFor(
      width: overlay ? 40 : 48,
      height: overlay ? 40 : 48,
    ),
    icon: Builder(
      builder: (context) => Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: overlay
              ? Theme.of(context).colorScheme.surface.withValues(alpha: .92)
              : Theme.of(context).colorScheme.surfaceContainerLow,
          shape: BoxShape.circle,
          boxShadow: overlay
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .14),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(
          Icons.close_rounded,
          size: 17,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );

  Widget _preview(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final image = ClipRRect(
      key: ValueKey('tab-preview-${tab.id}'),
      borderRadius: tabPreviewCorners,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors.surfaceContainerLow,
              colors.surfaceContainerHighest,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: tab.thumbnail != null
            ? Image.memory(
                tab.thumbnail!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => Center(
                  child: Icon(
                    Icons.public_rounded,
                    color: colors.primary,
                    size: 40,
                  ),
                ),
              )
            : Center(
                child: tab.atHome
                    ? const CrockLogo(size: 48)
                    : Icon(
                        Icons.public_rounded,
                        color: colors.primary,
                        size: 40,
                      ),
              ),
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        if (previewHero)
          Hero(
            key: tabPreviewHeroKey,
            tag: tabWindowHero(tab.id),
            curve: tabWindowCurve,
            reverseCurve: tabWindowCurve,
            createRectTween: tabWindowRectTween,
            flightShuttleBuilder: tabFlightFor(tab),
            child: image,
          )
        else
          image,
        if (showClose)
          Positioned(top: 4, right: 4, child: _close(overlay: true)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    elevation: 2,
    shadowColor: Theme.of(context).colorScheme.shadow.withValues(alpha: .18),
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(
        color: selected
            ? CrockTheme.blue
            : Theme.of(context).colorScheme.outlineVariant,
        width: 1,
      ),
    ),
    child: InkWell(
      onTap: onSelect,
      child: grid
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: _preview(context),
                      ),
                    ],
                  ),
                ),
                Padding(
                  key: ValueKey('tab-metadata-${tab.id}'),
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        host,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
              child: Row(
                children: [
                  const CrockLogo(size: 34),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          host,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (showClose) _close(),
                ],
              ),
            ),
    ),
  );
}
