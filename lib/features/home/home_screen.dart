import 'package:flutter/material.dart';

import '../../core/storage/browser_store.dart';
import '../../core/theme/crock_theme.dart';
import '../../shared/widgets/crock_logo.dart';
import 'widgets/home_bookmarks.dart';
import 'widgets/recent_sites.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.store,
    required this.onSearch,
    required this.onTool,
    required this.onShortcut,
    required this.onEditShortcut,
    required this.privateMode,
  });
  final BrowserStore store;
  final bool privateMode;
  final ValueChanged<String> onSearch, onTool;
  final ValueChanged<Map<String, dynamic>> onShortcut, onEditShortcut;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final privateBackground = Theme.of(context).brightness == Brightness.dark
        ? colors.surfaceContainerLow
        : const Color(0xFFECE9FA);
    final tools = [
      ('Downloads', Icons.download_rounded, 'downloads', CrockTheme.blue),
      (
        'Bookmarks',
        Icons.bookmark_outline_rounded,
        'bookmarks',
        const Color(0xFF02BCA8),
      ),
      (
        'Media',
        Icons.play_circle_outline_rounded,
        'media',
        const Color(0xFF9064ED),
      ),
      ('Files', Icons.folder_outlined, 'files', const Color(0xFFFFB529)),
      ('More', Icons.grid_view_rounded, 'menu', CrockTheme.cyan),
    ];
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: box.maxHeight),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomRight,
                colors: privateMode
                    ? [privateBackground, colors.surface]
                    : [colors.surface, colors.surfaceContainerLow],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: privateMode
                              ? const Chip(
                                  avatar: Icon(
                                    Icons.visibility_off_outlined,
                                    size: 17,
                                  ),
                                  label: Text('Private session'),
                                )
                              : Text(
                                  'YOUR WINDOW TO THE WEB',
                                  style: TextStyle(
                                    fontSize: 10,
                                    letterSpacing: 2,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Scan QR code',
                        onPressed: () => onTool('qr'),
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                      ),
                    ],
                  ),
                  SizedBox(height: box.maxHeight > 650 ? 64 : 28),
                  const CrockLogo(size: 76),
                  const SizedBox(height: 18),
                  Text(
                    privateMode ? 'Browse privately' : 'Crock Browser',
                    style: TextStyle(
                      color: colors.onSurface,
                      fontSize: 34,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0E1B3C66),
                          blurRadius: 28,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: TextField(
                      key: ValueKey(privateMode),
                      textInputAction: TextInputAction.go,
                      keyboardType: TextInputType.webSearch,
                      autocorrect: true,
                      onSubmitted: onSearch,
                      decoration: InputDecoration(
                        hintText: 'Search or enter URL',
                        hintStyle: const TextStyle(fontSize: 16),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: Icon(Icons.search_rounded, size: 25),
                        ),
                        filled: false,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(36),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 21,
                          horizontal: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: tools
                        .map(
                          (tool) => Expanded(
                            child: _HomeTool(
                              title: tool.$1,
                              color: tool.$4,
                              icon: tool.$2,
                              onTap: () => onTool(tool.$3),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 25),
                  HomeBookmarks(
                    sites: store.rows('shortcuts'),
                    onOpen: onShortcut,
                    onEdit: onEditShortcut,
                    onManage: () => onTool('shortcuts'),
                    allowIconNetwork: !privateMode,
                  ),
                  if (!privateMode) ...[
                    const SizedBox(height: 12),
                    RecentSites(
                      history: store.rows('history'),
                      onOpen: onSearch,
                      onViewAll: () => onTool('history'),
                    ),
                  ],
                  const SizedBox(height: 32),
                  Text(
                    privateMode
                        ? 'Private history and tabs stay out of your saved session.'
                        : 'A little curiosity. A whole wide web.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  if (privateMode)
                    TextButton(
                      onPressed: () => onTool('closePrivate'),
                      child: const Text('Close private session'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTool extends StatelessWidget {
  const _HomeTool({
    required this.title,
    required this.color,
    required this.onTap,
    required this.icon,
  });
  final String title;
  final Color color;
  final VoidCallback onTap;
  final IconData icon;
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 25),
          ),
          const SizedBox(height: 9),
          Text(
            title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 11,
              height: 1.25,
            ),
          ),
        ],
      ),
    ),
  );
}
