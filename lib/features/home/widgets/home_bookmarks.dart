import 'package:flutter/material.dart';

import '../../../shared/widgets/site_icon.dart';

class HomeBookmarks extends StatelessWidget {
  const HomeBookmarks({
    super.key,
    required this.sites,
    required this.onOpen,
    required this.onEdit,
    required this.onManage,
    this.allowIconNetwork = true,
  });
  final List<Map<String, dynamic>> sites;
  final ValueChanged<Map<String, dynamic>> onOpen, onEdit;
  final VoidCallback onManage;
  final bool allowIconNetwork;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pinned = sites.take(7).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Bookmarks',
                style: TextStyle(
                  color: colors.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: onManage,
              child: Text(sites.length > 7 ? 'View all' : 'Manage'),
            ),
          ],
        ),
        const SizedBox(height: 2),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: 8,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 2,
            mainAxisExtent:
                92 +
                ((MediaQuery.textScalerOf(context).scale(11) - 11) * 2.4).clamp(
                  0,
                  100,
                ),
          ),
          itemBuilder: (context, index) {
            if (index > pinned.length) return const SizedBox.shrink();
            final add = index == pinned.length;
            final site = add ? <String, dynamic>{} : pinned[index];
            final title = site['title']?.toString().trim() ?? '';
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => add ? onEdit({}) : onOpen(site),
              onLongPress: add ? null : () => onEdit(site),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(color: colors.outlineVariant),
                      ),
                      child: add
                          ? Icon(
                              Icons.add_rounded,
                              size: 28,
                              color: colors.onSurfaceVariant,
                            )
                          : SiteIcon(
                              url: site['url']?.toString() ?? '',
                              size: 36,
                              allowNetwork: allowIconNetwork,
                              fallbackLabel: title,
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      add ? 'Add site' : title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 11,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
