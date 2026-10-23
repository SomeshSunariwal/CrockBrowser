import 'package:flutter/material.dart';

import '../../core/storage/browser_store.dart';
import '../../core/theme/crock_theme.dart';
import '../../shared/widgets/crock_logo.dart';

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
                    ? [const Color(0xFFECE9FA), CrockTheme.background]
                    : [CrockTheme.background, const Color(0xFFEDF8FF)],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (privateMode)
                        const Chip(
                          avatar: Icon(Icons.visibility_off_outlined, size: 17),
                          label: Text('Private session'),
                        )
                      else
                        const Text(
                          'YOUR WINDOW TO THE WEB',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 2,
                            color: Color(0xFF8796A6),
                          ),
                        ),
                      const Spacer(),
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
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w300,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
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
                            child: _Shortcut(
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
                  GridView.count(
                    crossAxisCount: 5,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: .66,
                    children: [
                      ...store
                          .rows('shortcuts')
                          .map(
                            (site) => _Shortcut(
                              title: site['title'] as String,
                              initial: (site['title'] as String)
                                  .characters
                                  .first
                                  .toUpperCase(),
                              color: CrockTheme.blue,
                              subtle: true,
                              onTap: () => onShortcut(site),
                              onLongPress: () => onEditShortcut(site),
                            ),
                          ),
                      _Shortcut(
                        title: 'Add site',
                        icon: Icons.add_rounded,
                        color: const Color(0xFF8796A6),
                        subtle: true,
                        onTap: () => onEditShortcut({}),
                      ),
                    ],
                  ),
                  SizedBox(height: box.maxHeight > 650 ? 100 : 36),
                  Text(
                    privateMode
                        ? 'Private history and tabs stay out of your saved session.'
                        : 'A little curiosity. A whole wide web.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF8796A6),
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

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.title,
    required this.color,
    required this.onTap,
    this.icon,
    this.initial,
    this.subtle = false,
    this.onLongPress,
  });
  final String title;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final IconData? icon;
  final String? initial;
  final bool subtle;
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: onTap,
    onLongPress: onLongPress,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
      child: Column(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: subtle ? Colors.white : color,
            child: icon != null
                ? Icon(icon, color: subtle ? color : Colors.white, size: 25)
                : Text(
                    initial ?? '',
                    style: TextStyle(
                      fontSize: 25,
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(height: 9),
          Text(
            title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, height: 1.25),
          ),
        ],
      ),
    ),
  );
}
