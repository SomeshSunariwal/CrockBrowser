import 'package:flutter/material.dart';

import '../../core/storage/browser_store.dart';
import '../../shared/widgets/feature_scaffold.dart';

Future<void> editShortcut(
  BuildContext context,
  BrowserStore store, [
  Map<String, dynamic>? old,
]) async {
  final title = TextEditingController(text: old?['title'] as String? ?? ''),
      url = TextEditingController(text: old?['url'] as String? ?? '');
  await showCrockDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(old == null ? 'Add shortcut' : 'Edit shortcut'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: 'Site name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: url,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Website URL'),
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
            });
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final rows = store.rows('shortcuts');
      return FeatureScaffold(
        title: 'Home shortcuts',
        actions: [
          IconButton(
            tooltip: 'Add shortcut',
            onPressed: () => editShortcut(context, store),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
        child: ReorderableListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          onReorderItem: (oldIndex, newIndex) {
            final item = rows.removeAt(oldIndex);
            rows.insert(newIndex, item);
            store.setRows('shortcuts', rows);
          },
          itemBuilder: (context, index) => Card(
            key: ValueKey(rows[index]['id']),
            child: ListTile(
              leading: const Icon(
                Icons.language_rounded,
                color: Color(0xFF087CFA),
              ),
              title: Text(rows[index]['title'] as String),
              subtitle: Text(
                rows[index]['url'] as String,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.drag_handle_rounded),
              onTap: () => editShortcut(context, store, rows[index]),
            ),
          ),
        ),
      );
    },
  );
}
