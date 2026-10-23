import 'package:flutter/material.dart';

import '../../../shared/widgets/site_icon.dart';

class RecentSites extends StatelessWidget {
  const RecentSites({
    super.key,
    required this.history,
    required this.onOpen,
    required this.onViewAll,
  });
  final List<Map<String, dynamic>> history;
  final ValueChanged<String> onOpen;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ordered = [...history]
      ..sort(
        (a, b) => ((b['created'] as num?) ?? 0).compareTo(
          (a['created'] as num?) ?? 0,
        ),
      );
    final seen = <String>{};
    final sites = ordered
        .where((entry) {
          final uri = Uri.tryParse(entry['url']?.toString() ?? '');
          if (uri == null ||
              !['http', 'https'].contains(uri.scheme) ||
              uri.host.isEmpty) {
            return false;
          }
          return seen.add(
            uri.host.toLowerCase().replaceFirst(RegExp(r'^www\.'), ''),
          );
        })
        .take(6)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recently visited',
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (sites.isNotEmpty)
              TextButton(onPressed: onViewAll, child: const Text('View all')),
          ],
        ),
        const SizedBox(height: 6),
        Card(
          child: sites.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        color: colors.onSurfaceVariant,
                        size: 24,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Sites you visit will appear here.',
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < sites.length; i++) ...[
                      if (i > 0) const Divider(indent: 56, endIndent: 12),
                      _site(context, sites[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _site(BuildContext context, Map<String, dynamic> site) {
    final colors = Theme.of(context).colorScheme;
    final url = site['url'].toString();
    final host = Uri.parse(url).host.replaceFirst(RegExp(r'^www\.'), '');
    final title = site['title']?.toString().trim() ?? '';
    return InkWell(
      onTap: () => onOpen(url),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SiteIcon(
                  url: url,
                  size: 24,
                  fallbackLabel: title.isEmpty ? host : title,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title.isEmpty ? host : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      host,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.north_east_rounded,
                color: colors.onSurfaceVariant,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
