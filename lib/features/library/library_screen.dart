import '../../shared/widgets/crock_dropdown.dart';

import 'package:flutter/material.dart';

import '../../core/platform/native_bridge.dart';
import '../../core/storage/browser_store.dart';
import '../../shared/widgets/feature_scaffold.dart';
import '../../shared/widgets/selected_builder.dart';
import '../../shared/widgets/sliver_card.dart';
import '../../shared/widgets/compact_list_row.dart';
import '../../shared/widgets/site_icon.dart';
import '../../shared/widgets/editor_dialog.dart';
import 'bookmark_exchange.dart';
import '../privacy/browsing_data_time_range.dart';
import '../settings/widgets/clear_website_data_dialog.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.store,
    required this.mode,
    required this.onOpen,
    required this.onOffline,
  });
  final BrowserStore store;
  final String mode;
  final ValueChanged<String> onOpen;
  final ValueChanged<Map<String, dynamic>> onOffline;
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String folder = '', search = '';
  BrowserRows offline = [];
  BrowserRows? _source;
  BrowserRows _filtered = [];
  String? _query;

  BrowserRows _visibleRows(BrowserRows source) {
    final searchText = search.toLowerCase();
    final query = '${widget.mode}/$folder/$searchText';
    if (identical(source, _source) && query == _query) return _filtered;
    _source = source;
    _query = query;
    _filtered = source
        .where(
          (item) =>
              (!bookmarks || (item['folder'] ?? '') == folder) &&
              ('${item['title']} ${item['url']}').toLowerCase().contains(
                searchText,
              ),
        )
        .toList();
    if (widget.mode == 'history') {
      _filtered.sort(
        (a, b) => ((b['created'] as num?) ?? 0).compareTo(
          (a['created'] as num?) ?? 0,
        ),
      );
    }
    return _filtered;
  }

  String get title => widget.mode == 'history'
      ? 'History'
      : widget.mode == 'offline'
      ? 'Offline pages'
      : 'Bookmarks';
  bool get bookmarks => widget.mode == 'bookmarks';
  @override
  void initState() {
    super.initState();
    if (widget.mode == 'offline') _loadOffline();
  }

  Future<void> _loadOffline() async {
    try {
      final rows = await NativeBridge.instance.list('offline.list');
      if (mounted) setState(() => offline = rows);
    } catch (error) {
      if (mounted) crockMessage(context, error);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => SelectedBuilder<(BrowserRows, BrowserRows)>(
    listenable: widget.store,
    select: () => (
      widget.mode == 'offline' ? offline : widget.store.readRows(widget.mode),
      widget.store.readRows('folders'),
    ),
    builder: (context, selection) {
      final rows = _visibleRows(selection.$1);
      final folders = bookmarks
          ? selection.$2.where((f) => (f['parent'] ?? '') == folder).toList()
          : <Map<String, dynamic>>[];
      return FeatureScaffold(
        title: title,
        actions: [
          if (bookmarks)
            IconButton(
              tooltip: 'New folder',
              onPressed: () => _folder(),
              icon: const Icon(Icons.create_new_folder_outlined),
            ),
          CrockPopupMenuButton<String>(
            onSelected: _action,
            itemBuilder: (context) => [
              if (bookmarks)
                const PopupMenuItem(
                  height: 40,
                  value: 'import',
                  child: Text('Import bookmarks'),
                ),
              if (bookmarks)
                const PopupMenuItem(
                  height: 40,
                  value: 'export',
                  child: Text('Export bookmarks'),
                ),
              if (widget.mode == 'history')
                const PopupMenuItem(
                  height: 40,
                  value: 'clear',
                  child: Text('Clear history'),
                ),
            ],
          ),
        ],
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: TextField(
                onChanged: (value) => setState(() => search = value),
                decoration: InputDecoration(
                  hintText: 'Search ${title.toLowerCase()}',
                  isDense: true,
                  constraints: const BoxConstraints(minHeight: 36),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 36,
                  ),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 12, right: 8),
                    child: Icon(Icons.search_rounded, size: 20),
                  ),
                ),
              ),
            ),
            if (folder.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.arrow_upward_rounded),
                title: const Text('Parent folder'),
                onTap: () {
                  final parent = widget.store
                      .readRows('folders')
                      .where((f) => f['id'] == folder);
                  setState(
                    () => folder = parent.isEmpty
                        ? ''
                        : parent.first['parent'] as String? ?? '',
                  );
                },
              ),
            Expanded(
              child: rows.isEmpty && folders.isEmpty
                  ? CrockEmpty(
                      title: 'Nothing saved here yet',
                      detail: bookmarks
                          ? 'Add a page from the browser menu, create a folder or import a bookmarks file.'
                          : widget.mode == 'offline'
                          ? 'Choose Save offline from a webpage to keep a local copy.'
                          : 'Pages you visit in normal browsing appear here.',
                    )
                  : CustomScrollView(
                      key: PageStorageKey('library-${widget.mode}-$folder'),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          sliver: SliverMainAxisGroup(
                            slivers: [
                              if (folders.isNotEmpty)
                                SliverCard(
                                  sliver: SliverList.builder(
                                    itemCount: folders.length,
                                    itemBuilder: (context, index) =>
                                        CardListItem(
                                          key: ValueKey(folders[index]['id']),
                                          index: index,
                                          count: folders.length,
                                          child: _folderEntry(folders[index]),
                                        ),
                                  ),
                                ),
                              ..._itemGroups(context, rows),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      );
    },
  );
  Widget _folderEntry(Map<String, dynamic> item) => CompactListRow(
    leading: const Icon(Icons.folder_outlined, color: Color(0xFF087CFA)),
    title: Text(item['title'] as String),
    onTap: () => setState(() => folder = item['id'] as String),
    trailing: CrockPopupMenuButton<String>(
      onSelected: (action) =>
          action == 'rename' ? _folder(item) : _removeFolder(item),
      itemBuilder: (_) => const [
        PopupMenuItem(height: 40, value: 'rename', child: Text('Rename')),
        PopupMenuItem(
          height: 40,
          value: 'remove',
          child: Text('Remove folder'),
        ),
      ],
    ),
  );

  Widget _entry(Map<String, dynamic> item) => CompactListRow(
    leading: widget.mode == 'offline'
        ? const Icon(Icons.offline_pin_outlined, color: Color(0xFF087CFA))
        : SiteIcon(
            url: item['url'] as String? ?? '',
            fallbackLabel: item['title'] as String? ?? '',
            size: 24,
          ),
    title: Text(
      item['title'] as String? ?? item['url'] as String? ?? 'Saved page',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    subtitle: Text(
      item['url'] as String? ?? '',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    onTap: () {
      Navigator.pop(context);
      if (widget.mode == 'offline') {
        widget.onOffline(item);
      } else {
        widget.onOpen(item['url'] as String);
      }
    },
    trailing: CrockPopupMenuButton<String>(
      onSelected: (action) => action == 'edit' ? _edit(item) : _remove(item),
      itemBuilder: (context) => [
        if (bookmarks)
          const PopupMenuItem(
            height: 40,
            value: 'edit',
            child: Text('Edit / move'),
          ),
        const PopupMenuItem(height: 40, value: 'remove', child: Text('Remove')),
      ],
    ),
  );

  Iterable<Widget> _itemGroups(
    BuildContext context,
    List<Map<String, dynamic>> rows,
  ) sync* {
    final groups = <String, List<Map<String, dynamic>>>{};
    if (widget.mode == 'history') {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = DateTime(today.year, today.month, today.day - 1);
      for (final row in rows) {
        final timestamp = row['created'] as num?;
        String label = 'Unknown date';
        if (timestamp != null) {
          final date = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
          final day = DateTime(date.year, date.month, date.day);
          label = day == today
              ? 'Today'
              : day == yesterday
              ? 'Yesterday'
              : MaterialLocalizations.of(context).formatFullDate(day);
        }
        groups.putIfAbsent(label, () => []).add(row);
      }
    } else if (rows.isNotEmpty) {
      groups[''] = rows;
    }
    for (final (index, group) in groups.entries.indexed) {
      if (group.key.isNotEmpty) {
        yield SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(4, index == 0 ? 0 : 12, 4, 8),
            child: Text(
              group.key,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        );
      }
      yield SliverCard(
        sliver: SliverList.builder(
          itemCount: group.value.length,
          itemBuilder: (context, index) => CardListItem(
            key: ValueKey(group.value[index]['id']),
            index: index,
            count: group.value.length,
            child: _entry(group.value[index]),
          ),
        ),
      );
    }
  }

  Future<void> _folder([Map<String, dynamic>? old]) async {
    final input = TextEditingController(text: old?['title'] as String? ?? '');
    final value = await showCrockDialog<String>(
      context: context,
      builder: (context) => CrockEditorDialog(
        title: old == null ? 'New folder' : 'Rename folder',
        content: CrockEditorField(
          label: 'Folder name',
          controller: input,
          autofocus: true,
          textInputAction: TextInputAction.done,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, input.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    input.dispose();
    if (value != null && value.isNotEmpty) {
      widget.store.add('folders', {
        'id': old?['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
        'title': value,
        'parent': old?['parent'] ?? folder,
      });
    }
  }

  Future<void> _removeFolder(Map<String, dynamic> item) async {
    if (!await confirmCrock(
      context,
      'Remove folder?',
      'Its bookmarks and child folders will move to the parent folder.',
    )) {
      return;
    }
    final id = item['id'], parent = item['parent'] ?? '';
    widget.store.setRows(
      'bookmarks',
      widget.store
          .readRows('bookmarks')
          .map((row) => row['folder'] == id ? {...row, 'folder': parent} : row)
          .toList(),
    );
    widget.store.setRows(
      'folders',
      widget.store
          .readRows('folders')
          .where((f) => f['id'] != id)
          .map((f) => f['parent'] == id ? {...f, 'parent': parent} : f)
          .toList(),
    );
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final name = TextEditingController(text: item['title'] as String? ?? ''),
        url = TextEditingController(text: item['url'] as String? ?? '');
    String target = item['folder'] as String? ?? '';
    await showCrockDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => CrockEditorDialog(
          title: 'Edit bookmark',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CrockEditorField(
                label: 'Title',
                controller: name,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              CrockEditorField(
                label: 'Website URL',
                controller: url,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 12),
              CrockDropdownButtonFormField<String>(
                initialValue: target,
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Bookmarks root'),
                  ),
                  ...widget.store
                      .readRows('folders')
                      .map(
                        (f) => DropdownMenuItem(
                          value: f['id'] as String,
                          child: Text(f['title'] as String),
                        ),
                      ),
                ],
                onChanged: (value) => setLocal(() => target = value ?? ''),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final uri = Uri.tryParse(url.text.trim());
                if (uri == null ||
                    !['http', 'https'].contains(uri.scheme) ||
                    uri.host.isEmpty) {
                  crockMessage(context, 'Enter a valid web address');
                  return;
                }
                widget.store.add('bookmarks', {
                  ...item,
                  'title': name.text.trim().isEmpty
                      ? url.text
                      : name.text.trim(),
                  'url': url.text.trim(),
                  'folder': target,
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    url.dispose();
  }

  Future<void> _remove(Map<String, dynamic> row) async {
    if (widget.mode == 'offline') {
      await NativeBridge.instance.call('offline.remove', {'id': row['id']});
      await _loadOffline();
    } else {
      widget.store.remove(widget.mode, row['id'] as String);
    }
  }

  Future<void> _action(String action) async {
    try {
      if (action == 'clear') {
        final selection = await showCrockDialog<BrowsingDataSelection>(
          context: context,
          builder: (_) => const ClearWebsiteDataDialog(historyOnly: true),
        );
        if (selection != null) {
          widget.store.setRows(
            'history',
            historyOutsideTimeRange(
              widget.store.readRows('history'),
              selection.timeRange,
              DateTime.now(),
            ),
          );
          await widget.store.flush();
          if (widget.store.saveError != null) {
            throw StateError(widget.store.saveError!);
          }
          if (mounted) crockMessage(context, 'History cleared');
        }
      }
      if (action == 'import') {
        final input = await NativeBridge.instance.call<Map>('files.pickText');
        if (input == null) return;
        final parsed = BookmarkExchange.parse(input['text'] as String);
        widget.store.setRows('folders', [
          ...widget.store.readRows('folders'),
          ...parsed['folders']!,
        ]);
        widget.store.setRows('bookmarks', [
          ...widget.store.readRows('bookmarks'),
          ...parsed['bookmarks']!,
        ]);
        if (mounted) {
          crockMessage(
            context,
            'Imported ${parsed['bookmarks']!.length} bookmarks',
          );
        }
      }
      if (action == 'export') {
        await NativeBridge.instance.call('files.exportText', {
          'name': 'Crock Bookmarks.html',
          'mime': 'text/html',
          'text': BookmarkExchange.html(
            widget.store.readRows('bookmarks'),
            widget.store.readRows('folders'),
          ),
        });
      }
    } catch (error) {
      if (mounted) crockMessage(context, error);
    }
  }
}
