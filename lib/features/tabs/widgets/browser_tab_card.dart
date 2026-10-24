import 'package:flutter/material.dart';

import '../../../core/models/browser_tab.dart';
import '../../../core/theme/crock_theme.dart';
import '../../../shared/widgets/crock_logo.dart';

class BrowserTabCard extends StatelessWidget {
  const BrowserTabCard({
    super.key,
    required this.tab,
    required this.selected,
    required this.grid,
    required this.onSelect,
    required this.onClose,
  });
  final BrowserTab tab;
  final bool selected, grid;
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
        width: selected ? 1.0 : 1,
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
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16),
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerLow,
                                  Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: tab.thumbnail != null && !tab.atHome
                                ? Image.memory(
                                    tab.thumbnail!,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                    alignment: Alignment.topCenter,
                                    gaplessPlayback: true,
                                    errorBuilder: (_, error, stackTrace) =>
                                        const Center(
                                          child: Icon(
                                            Icons.public_rounded,
                                            size: 40,
                                            color: CrockTheme.blue,
                                          ),
                                        ),
                                  )
                                : Center(
                                    child: tab.atHome
                                        ? const CrockLogo(size: 48)
                                        : const Icon(
                                            Icons.public_rounded,
                                            size: 40,
                                            color: CrockTheme.blue,
                                          ),
                                  ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: _close(overlay: true),
                      ),
                    ],
                  ),
                ),
                Padding(
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
                  const SizedBox(width: 14),
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
                  _close(),
                ],
              ),
            ),
    ),
  );
}
