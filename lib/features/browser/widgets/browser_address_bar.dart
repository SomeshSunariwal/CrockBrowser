import 'package:flutter/material.dart';

import '../../../core/theme/crock_theme.dart';
import '../../../shared/widgets/crock_notification.dart';

class BrowserAddressBar extends StatelessWidget {
  const BrowserAddressBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.url,
    required this.onHome,
    required this.onSubmit,
    required this.onMenuSelected,
    required this.onTabs,
    required this.tabCount,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final String url;
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
                  width: 1.5,
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
            child: PopupMenuButton<String>(
              tooltip: 'More browser options',
              padding: EdgeInsets.zero,
              iconSize: 22,
              position: PopupMenuPosition.under,
              offset: const Offset(0, 6),
              onOpened: () => crockNotificationObscured.value = true,
              onCanceled: () => crockNotificationObscured.value = false,
              onSelected: (value) {
                crockNotificationObscured.value = false;
                onMenuSelected(value);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'back',
                  child: _BrowserMenuItem(
                    icon: Icons.arrow_back_rounded,
                    label: 'Back',
                  ),
                ),
                PopupMenuItem(
                  value: 'newTab',
                  child: _BrowserMenuItem(
                    icon: Icons.add_rounded,
                    label: 'New Tab',
                  ),
                ),
                PopupMenuItem(
                  value: 'newPrivateTab',
                  child: _BrowserMenuItem(
                    icon: Icons.visibility_off_outlined,
                    label: 'New Private Tab',
                  ),
                ),
                PopupMenuItem(
                  value: 'history',
                  child: _BrowserMenuItem(
                    icon: Icons.history_rounded,
                    label: 'History',
                  ),
                ),
                PopupMenuItem(
                  value: 'downloads',
                  child: _BrowserMenuItem(
                    icon: Icons.download_rounded,
                    label: 'Downloads',
                  ),
                ),
                PopupMenuItem(
                  value: 'find',
                  child: _BrowserMenuItem(
                    icon: Icons.search_rounded,
                    label: 'Find in page',
                  ),
                ),
                PopupMenuItem(
                  value: 'refresh',
                  child: _BrowserMenuItem(
                    icon: Icons.refresh_rounded,
                    label: 'Refresh page',
                  ),
                ),
                PopupMenuItem(
                  value: 'browserMenu',
                  child: _BrowserMenuItem(
                    icon: Icons.grid_view_rounded,
                    label: 'Browser menu',
                  ),
                ),
                PopupMenuItem(
                  value: 'closeTab',
                  child: _BrowserMenuItem(
                    icon: Icons.close_rounded,
                    label: 'Close tab',
                  ),
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
    children: [
      Icon(icon, size: 20, color: CrockTheme.blue),
      const SizedBox(width: 14),
      Text(
        label,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
    ],
  );
}
