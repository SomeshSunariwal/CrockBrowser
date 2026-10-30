import 'package:flutter/material.dart';

import '../../../shared/widgets/site_icon.dart';
import '../../../shared/widgets/compact_list_row.dart';

class RecentSites extends StatefulWidget {
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
  State<RecentSites> createState() => _RecentSitesState();
}

class _RecentSitesState extends State<RecentSites> {
  late List<Map<String, dynamic>> _sites;
  @override
  void initState() {
    super.initState();
    _selectSites();
  }

  @override
  void didUpdateWidget(covariant RecentSites oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.history, widget.history)) _selectSites();
  }

  void _selectSites() {
    final ordered = [...widget.history]
      ..sort(
        (a, b) => ((b['created'] as num?) ?? 0).compareTo(
          (a['created'] as num?) ?? 0,
        ),
      );
    final seen = <String>{};
    _sites = ordered
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
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 36,
          child: Row(
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
              if (_sites.isNotEmpty)
                TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(64, 32),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    alignment: Alignment.centerRight,
                  ),
                  onPressed: widget.onViewAll,
                  child: const Text('View all'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: _sites.isEmpty
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
                    for (var i = 0; i < _sites.length; i++) ...[
                      if (i > 0) const Divider(indent: 56, endIndent: 12),
                      _site(context, _sites[i]),
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
    return CompactListRow(
      onTap: () => widget.onOpen(url),
      leading: Container(
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
      title: Text(title.isEmpty ? host : title),
      subtitle: Text(host),
      trailing: Icon(
        Icons.north_east_rounded,
        color: colors.onSurfaceVariant,
        size: 17,
      ),
    );
  }
}
