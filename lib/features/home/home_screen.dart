import '../../shared/widgets/crock_dropdown.dart';

import 'package:flutter/material.dart';

import '../../core/storage/browser_store.dart';
import '../../core/theme/crock_theme.dart';
import '../../shared/widgets/crock_logo.dart';
import '../../shared/widgets/site_icon.dart';
import 'widgets/home_bookmarks.dart';
import 'widgets/home_grid.dart';
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 112),
              child: Column(
                children: [
                  Row(
                    children: [
                      const CrockLogo(size: 28),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          privateMode ? 'Browse privately' : 'Crock Browser',
                          style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      if (privateMode)
                        Tooltip(
                          message: 'Private session',
                          child: Icon(
                            Icons.visibility_off_outlined,
                            size: 20,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x201B3C66),
                          blurRadius: 20,
                          offset: Offset(0, 6),
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
                        hintStyle: const TextStyle(fontSize: 14),
                        prefixIcon: _SearchProviderPicker(
                          store: store,
                          privateMode: privateMode,
                        ),
                        suffixIcon: const Icon(Icons.search_rounded, size: 21),
                        filled: false,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate: HomeGrid.delegate(context),
                    children: [
                      for (final tool in tools)
                        HomeGridTile(
                          title: tool.$1,
                          color: tool.$4,
                          icon: Icon(tool.$2, color: Colors.white, size: 25),
                          onTap: () => onTool(tool.$3),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  HomeBookmarks(
                    sites: store.readRows('shortcuts'),
                    onOpen: onShortcut,
                    onEdit: onEditShortcut,
                    onManage: () => onTool('shortcuts'),
                    allowIconNetwork: !privateMode,
                  ),
                  if (!privateMode) ...[
                    const SizedBox(height: 12),
                    RecentSites(
                      history: store.readRows('history'),
                      onOpen: onSearch,
                      onViewAll: () => onTool('history'),
                    ),
                  ],
                  const SizedBox(height: 20),
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

/// Uses the same saved provider as Settings and BrowserController.resolve.
class _SearchProviderPicker extends StatelessWidget {
  const _SearchProviderPicker({required this.store, required this.privateMode});

  final BrowserStore store;
  final bool privateMode;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final engines = store.readRows('engines');
      final selectedId = store.setting('engine', 'google');
      final selected = engines.where((engine) => engine['id'] == selectedId);
      final current = selected.isNotEmpty
          ? selected.first
          : <String, dynamic>{
              'id': 'google',
              'name': 'Google',
              'url': 'https://www.google.com/search?q={query}',
            };
      Widget icon(Map<String, dynamic> engine) => SiteIcon(
        key: ValueKey(engine['id']),
        url: engine['url'] as String,
        fallbackLabel: engine['name'] as String,
        size: 22,
        allowNetwork: !privateMode,
      );
      return CrockPopupMenuButton<String>(
        tooltip: 'Search provider: ${current['name']}',
        position: PopupMenuPosition.under,
        initialValue: current['id'] as String,
        onSelected: (id) => store.setSetting('engine', id),
        itemBuilder: (context) => [
          for (final engine in engines)
            PopupMenuItem<String>(
              height: 40,
              value: engine['id'] as String,
              child: Row(
                children: [
                  icon(engine),
                  const SizedBox(width: 12),
                  Expanded(child: Text(engine['name'] as String)),
                  const SizedBox(width: 16),
                  if (engine['id'] == current['id'])
                    Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                ],
              ),
            ),
        ],
        child: Padding(
          padding: const EdgeInsets.only(left: 14, right: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              icon(current),
              const Icon(Icons.arrow_drop_down_rounded, size: 18),
            ],
          ),
        ),
      );
    },
  );
}
