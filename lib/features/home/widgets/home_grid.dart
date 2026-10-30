import 'package:flutter/material.dart';

abstract final class HomeGrid {
  static const iconSize = 48.0;
  static const iconRadius = 16.0;

  static SliverGridDelegateWithFixedCrossAxisCount delegate(
    BuildContext context,
  ) => SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 5,
    crossAxisSpacing: 6,
    mainAxisSpacing: 2,
    mainAxisExtent:
        88 +
        ((MediaQuery.textScalerOf(context).scale(11) - 11) * 2.4).clamp(0, 100),
  );
}

class HomeGridTile extends StatelessWidget {
  const HomeGridTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.onLongPress,
    this.color,
  });
  final String title;
  final Widget icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(HomeGrid.iconRadius),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Container(
              width: HomeGrid.iconSize,
              height: HomeGrid.iconSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color ?? colors.surface,
                borderRadius: BorderRadius.circular(HomeGrid.iconRadius),
                border: color == null
                    ? Border.all(color: colors.outlineVariant)
                    : null,
              ),
              child: icon,
            ),
            const SizedBox(height: 6),
            Text(
              title,
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
  }
}
