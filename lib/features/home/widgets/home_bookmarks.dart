import 'package:flutter/material.dart';

import '../../../shared/widgets/site_icon.dart';
import 'home_grid.dart';

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
    final pinned = sites.take(9).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 36,
          child: Row(
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
                style: TextButton.styleFrom(
                  minimumSize: const Size(64, 32),
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  alignment: Alignment.centerRight,
                ),
                onPressed: onManage,
                child: Text(sites.length > 9 ? 'View all' : 'Manage'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: pinned.length + 1,
          gridDelegate: HomeGrid.delegate(context),
          itemBuilder: (context, index) {
            final add = index == pinned.length;
            final site = add ? <String, dynamic>{} : pinned[index];
            final title = site['title']?.toString().trim() ?? '';
            return HomeGridTile(
              title: add ? 'Add site' : title,
              onTap: () => add ? onEdit({}) : onOpen(site),
              onLongPress: add ? null : () => onEdit(site),
              icon: add
                  ? Icon(
                      Icons.add_rounded,
                      size: 28,
                      color: colors.onSurfaceVariant,
                    )
                  : SiteIcon(
                      url: site['url']?.toString() ?? '',
                      size: 30,
                      allowNetwork: allowIconNetwork,
                      fallbackLabel: title,
                    ),
            );
          },
        ),
      ],
    );
  }
}
