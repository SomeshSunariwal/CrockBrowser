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

  Widget _close() => IconButton(
    tooltip: 'Close $title tab',
    onPressed: onClose,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 48, height: 48),
    icon: Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        color: Color(0xFFF0F4F9),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.close_rounded, size: 17, color: CrockTheme.muted),
    ),
  );

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(
        color: selected ? CrockTheme.blue : CrockTheme.line,
        width: selected ? 1.5 : 1,
      ),
    ),
    child: InkWell(
      onTap: onSelect,
      child: grid
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(child: CrockLogo(size: 28)),
                      ),
                      const Spacer(),
                      _close(),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF1F8FF), Color(0xFFE8F5FC)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CrockTheme.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        host,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CrockTheme.muted,
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
                          maxLines: 2,
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
