import 'package:flutter/material.dart';

import '../../core/storage/browser_store.dart';
import '../../shared/widgets/feature_scaffold.dart';
import '../../shared/widgets/selected_builder.dart';
import '../../shared/widgets/sliver_card.dart';
import '../../shared/widgets/compact_list_row.dart';
import '../../shared/widgets/site_icon.dart';
import '../../shared/widgets/editor_dialog.dart';

Future<void> editShortcut(
  BuildContext context,
  BrowserStore store, [
  Map<String, dynamic>? old,
]) async {
  final title = TextEditingController(text: old?['title'] as String? ?? ''),
      url = TextEditingController(text: old?['url'] as String? ?? '');
  await showCrockDialog<void>(
    context: context,
    builder: (context) => CrockDialog(
      title: Text(old == null ? 'Add shortcut' : 'Edit shortcut'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CrockEditorField(
            label: 'Site name',
            hintText: 'e.g. Wikipedia',
            controller: title,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          CrockEditorField(
            label: 'Website URL',
            hintText: 'https://example.com',
            controller: url,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
      actions: [
        if (old != null)
          TextButton(
            onPressed: () {
              store.remove('shortcuts', old['id'] as String);
              Navigator.pop(context);
            },
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = url.text.trim();
            final uri = Uri.tryParse(
              value.contains('://') ? value : 'https://$value',
            );
            if (title.text.trim().isEmpty ||
                uri == null ||
                !['http', 'https'].contains(uri.scheme) ||
                uri.host.isEmpty) {
              crockMessage(context, 'Enter a site name and valid website URL');
              return;
            }
            store.add('shortcuts', {
              'id':
                  old?['id'] ??
                  DateTime.now().microsecondsSinceEpoch.toString(),
              'title': title.text.trim(),
              'url': uri.toString(),
            }, prepend: false);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  title.dispose();
  url.dispose();
}

class ShortcutsScreen extends StatelessWidget {
  const ShortcutsScreen({super.key, required this.store});
  final BrowserStore store;
  @override
  Widget build(BuildContext context) => SelectedBuilder<BrowserRows>(
    listenable: store,
    select: () => store.readRows('shortcuts'),
    builder: (context, rows) {
      return FeatureScaffold(
        title: 'Home shortcuts',
        actions: [
          IconButton(
            tooltip: 'Add shortcut',
            onPressed: () => editShortcut(context, store),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
        child: CustomScrollView(
          key: const PageStorageKey('home-shortcuts'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverCard(
                sliver: SliverReorderableList(
                  itemCount: rows.length,
                  onReorderItem: (oldIndex, newIndex) {
                    final reordered = List<Map<String, dynamic>>.of(rows);
                    final item = reordered.removeAt(oldIndex);
                    reordered.insert(newIndex, item);
                    store.setRows('shortcuts', reordered);
                  },
                  itemBuilder: (context, index) => CardListItem(
                    key: ValueKey(rows[index]['id']),
                    index: index,
                    count: rows.length,
                    child: CompactListRow(
                      leading: SiteIcon(
                        url: rows[index]['url'] as String,
                        fallbackLabel: rows[index]['title'] as String,
                        size: 24,
                      ),
                      title: Text(rows[index]['title'] as String),
                      subtitle: Text(
                        rows[index]['url'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: ReorderableDragStartListener(
                        index: index,
                        child: Icon(
                          Icons.drag_handle_rounded,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      onTap: () => editShortcut(context, store, rows[index]),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
