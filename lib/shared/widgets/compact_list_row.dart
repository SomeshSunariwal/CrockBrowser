import 'package:flutter/material.dart';

/// Shared two-line density used by the browser's saved-item lists.
class CompactListRow extends StatelessWidget {
  const CompactListRow({
    super.key,
    required this.title,
    required this.leading,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.minHeight = 56,
    this.leadingWidth = 32,
    this.titleGap = 8,
    this.trailingWidth = 32,
    this.trailingHeight = 32,
  });

  final Widget title, leading;
  final Widget? subtitle, trailing;
  final VoidCallback? onTap;
  final double minHeight, leadingWidth, titleGap;
  final double? trailingWidth, trailingHeight;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: leadingWidth,
                height: leadingWidth,
                child: Center(child: leading),
              ),
              SizedBox(width: titleGap),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DefaultTextStyle(
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: title,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      DefaultTextStyle(
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 11,
                          height: 1.45,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        child: subtitle!,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: trailingWidth,
                  height: trailingHeight,
                  child: Center(child: trailing),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
