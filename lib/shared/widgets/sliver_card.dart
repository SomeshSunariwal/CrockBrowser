import 'package:flutter/material.dart';

/// A card background for lazily built rows, without a shrink-wrapped viewport.
class SliverCard extends StatelessWidget {
  const SliverCard({super.key, required this.sliver});
  final Widget sliver;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedSliver(
      decoration: ShapeDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        shape:
            theme.cardTheme.shape ??
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
      ),
      sliver: sliver,
    );
  }
}

/// Paints ink above the card background and clips only the group's outer corners.
class CardListItem extends StatelessWidget {
  const CardListItem({
    super.key,
    required this.index,
    required this.count,
    required this.child,
    this.paintBackground = false,
  });
  final int index, count;
  final Widget child;
  final bool paintBackground;
  @override
  Widget build(BuildContext context) {
    final shape = Theme.of(context).cardTheme.shape;
    final radius = shape is RoundedRectangleBorder
        ? shape.borderRadius.resolve(Directionality.of(context))
        : BorderRadius.circular(24);
    final corners = BorderRadius.only(
      topLeft: index == 0 ? radius.topLeft : Radius.zero,
      topRight: index == 0 ? radius.topRight : Radius.zero,
      bottomLeft: index == count - 1 ? radius.bottomLeft : Radius.zero,
      bottomRight: index == count - 1 ? radius.bottomRight : Radius.zero,
    );
    final theme = Theme.of(context);
    final side = BorderSide(color: theme.colorScheme.outlineVariant);
    return DecoratedBox(
      decoration: paintBackground
          ? BoxDecoration(
              color: theme.cardTheme.color ?? theme.colorScheme.surface,
              borderRadius: corners,
              border: Border(
                left: side,
                right: side,
                top: index == 0 ? side : BorderSide.none,
                bottom: index == count - 1 ? side : BorderSide.none,
              ),
            )
          : const BoxDecoration(),
      child: Material(
        type: MaterialType.transparency,
        clipBehavior: Clip.antiAlias,
        borderRadius: corners,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (index > 0) const Divider(indent: 52, endIndent: 12),
            child,
          ],
        ),
      ),
    );
  }
}
