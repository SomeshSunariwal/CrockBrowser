import '../../../shared/widgets/crock_dropdown.dart';

import 'package:flutter/material.dart';

import '../../../core/storage/browser_store.dart';
import '../../../shared/widgets/selected_builder.dart';
import '../../../shared/widgets/crock_notification.dart';

class BrowserAddressBar extends StatelessWidget {
  const BrowserAddressBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.url,
    required this.store,
    required this.onHome,
    required this.onSubmit,
    required this.onMenuSelected,
    required this.onTabs,
    required this.tabCount,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final String url;
  final BrowserStore store;
  final VoidCallback onHome;
  final ValueChanged<String> onSubmit;
  final ValueChanged<String> onMenuSelected;
  final VoidCallback onTabs;
  final int tabCount;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surface,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Home',
            onPressed: onHome,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: Icon(
              Icons.home_outlined,
              size: 24,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              style: TextStyle(
                fontSize: 14,
                height: 1.25,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlignVertical: TextAlignVertical.center,
              textInputAction: TextInputAction.go,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                isDense: true,
                constraints: const BoxConstraints(minHeight: 36),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                hintText: 'Search or enter URL',
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                prefixIcon: Icon(
                  url.startsWith('https://')
                      ? Icons.lock_outline_rounded
                      : Icons.public_rounded,
                  size: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              onTap: () => controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: controller.text.length,
              ),
              onSubmitted: onSubmit,
            ),
          ),
          IconButton(
            tooltip: '$tabCount open tabs',
            onPressed: onTabs,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: Container(
              width: 20,
              height: 23,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(
                  width: 1,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                '$tabCount',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(
            width: 40,
            height: 40,
            child: CrockPopupMenuButton<String>(
              tooltip: 'More browser options',
              padding: EdgeInsets.zero,
              iconSize: 22,
              menuPadding: const EdgeInsets.symmetric(vertical: 4),
              clipBehavior: Clip.antiAlias,
              constraints: const BoxConstraints.tightFor(width: 188),
              position: PopupMenuPosition.under,
              offset: const Offset(0, 6),
              onOpened: () => crockNotificationObscured.value = true,
              onCanceled: () => crockNotificationObscured.value = false,
              onSelected: (value) {
                crockNotificationObscured.value = false;
                onMenuSelected(value);
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  enabled: false,
                  height: 40,
                  padding: EdgeInsets.zero,
                  child: IconTheme.merge(
                    data: const IconThemeData(opacity: 1),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _ToolbarAction(
                          tooltip: 'Back',
                          icon: Icons.arrow_back_rounded,
                          onPressed: () => Navigator.of(context).pop('back'),
                        ),
                        SelectedBuilder<bool>(
                          listenable: store,
                          select: () => store
                              .readRows('bookmarks')
                              .any((bookmark) => bookmark['url'] == url),
                          builder: (context, saved) => _ToolbarAction(
                            tooltip: saved ? 'Remove bookmark' : 'Bookmark',
                            icon: saved
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            selected: saved,
                            color: saved ? const Color(0xFFFFC107) : null,
                            onPressed: () => onMenuSelected('toggleBookmark'),
                          ),
                        ),
                        _ToolbarAction(
                          tooltip: 'Reload',
                          icon: Icons.refresh_rounded,
                          onPressed: () => Navigator.of(context).pop('refresh'),
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuDivider(
                  height: 4,
                  thickness: 1,
                  indent: 12,
                  endIndent: 12,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                for (final (value, icon, label) in const [
                  ('newTab', Icons.add_rounded, 'New Tab'),
                  (
                    'newPrivateTab',
                    Icons.visibility_off_outlined,
                    'New Private Tab',
                  ),
                  ('bookmarks', Icons.star_border_rounded, 'Bookmarks'),
                  ('history', Icons.history_rounded, 'History'),
                  ('downloads', Icons.download_rounded, 'Download'),
                  (
                    'saveOffline',
                    Icons.offline_pin_outlined,
                    'Save page offline',
                  ),
                  ('find', Icons.search_rounded, 'Find in page'),
                ])
                  PopupMenuItem(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    value: value,
                    child: _BrowserMenuItem(icon: icon, label: label),
                  ),
                PopupMenuDivider(
                  height: 4,
                  thickness: 1,
                  indent: 12,
                  endIndent: 12,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                for (final (value, icon, label) in const [
                  ('browserMenu', Icons.grid_view_rounded, 'Browser Menu'),
                  ('closeTab', Icons.close_rounded, 'Close Tab'),
                ])
                  PopupMenuItem(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    value: value,
                    child: _BrowserMenuItem(icon: icon, label: label),
                  ),
              ],
              icon: Icon(
                Icons.more_vert_rounded,
                size: 22,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BrowserMenuItem extends StatelessWidget {
  const _BrowserMenuItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      SizedBox(
        width: 28,
        height: 28,
        child: Center(
          child: Icon(
            icon,
            size: 24,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.2,
          ),
          strutStyle: const StrutStyle(height: 1.2, forceStrutHeight: true),
        ),
      ),
    ],
  );
}

class _ToolbarAction extends StatelessWidget {
  const _ToolbarAction({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color,
    this.selected = false,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final bool selected;
  @override
  Widget build(BuildContext context) => IconButton(
    style: const ButtonStyle(
      padding: WidgetStatePropertyAll(EdgeInsets.zero),
      minimumSize: WidgetStatePropertyAll(Size(40, 40)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
    ),
    tooltip: tooltip,
    isSelected: selected,
    onPressed: onPressed,
    icon: Icon(
      icon,
      size: 24,
      color: color ?? Theme.of(context).colorScheme.primary,
    ),
  );
}
