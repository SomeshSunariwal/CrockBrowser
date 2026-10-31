import 'package:flutter/material.dart';

import '../../../core/theme/crock_theme.dart';
import '../../../shared/widgets/crock_dropdown.dart';
import '../../../shared/widgets/compact_list_row.dart';

class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
  });
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                const Padding(
                  padding: EdgeInsets.only(left: 54),
                  child: Divider(),
                ),
              children[i],
            ],
          ],
        ),
      ),
    ],
  );
}

class SettingsIcon extends StatelessWidget {
  const SettingsIcon(this.icon, {super.key, this.color = CrockTheme.blue});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Icon(icon, color: color, size: 19),
  );
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
    return CompactListRow(
      minHeight: 64 * (scale > 1 ? scale : 1),
      trailingWidth: null,
      trailingHeight: null,
      leadingWidth: 34,
      titleGap: 8,
      leading: SettingsIcon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing:
          trailing ??
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
      onTap: onTap,
    );
  }
}

class SettingsControlBox extends StatelessWidget {
  const SettingsControlBox({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: 144,
    constraints: const BoxConstraints(minHeight: 34),
    padding: const EdgeInsets.symmetric(vertical: 2),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(
        color: Theme.of(context).colorScheme.outlineVariant,
        width: 1,
      ),
    ),
    child: DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 12),
      child: child,
    ),
  );
}

/// A single layout for the settings page's compact select controls.
class SettingsDropdown extends StatelessWidget {
  const SettingsDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.icons,
  });
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;
  final Map<String, IconData>? icons;
  @override
  Widget build(BuildContext context) => SettingsControlBox(
    child: CrockDropdownButton<String>(
      value: options.containsKey(value) ? value : options.keys.first,
      isDense: true,
      isExpanded: true,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      itemIcons: icons,
      items: [
        for (final entry in options.entries)
          DropdownMenuItem(
            value: entry.key,
            child: Text(
              entry.value,
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: (value) {
        if (value != null) onChanged(value);
      },
    ),
  );
}
