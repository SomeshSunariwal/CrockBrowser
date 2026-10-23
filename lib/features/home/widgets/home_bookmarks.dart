import 'package:flutter/material.dart';

import '../../../core/theme/crock_theme.dart';
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
    final pinned = sites.take(7).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Bookmarks',
                style: TextStyle(
                  color: CrockTheme.ink,
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
                82 +
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
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: CrockTheme.line),
                      ),
                      child: add
                          ? const Icon(
                              Icons.add_rounded,
                              size: 23,
                              color: CrockTheme.muted,
                            )
                          : SiteIcon(
                              url: site['url']?.toString() ?? '',
                              size: 24,
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
                      style: const TextStyle(
                        color: CrockTheme.ink,
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
