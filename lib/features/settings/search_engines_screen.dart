import '../../core/theme/app_motion.dart';

import 'package:flutter/material.dart';

import '../../core/storage/browser_store.dart';
import '../../shared/widgets/feature_scaffold.dart';
import '../../shared/widgets/editor_dialog.dart';

class SearchEnginesScreen extends StatelessWidget {
  const SearchEnginesScreen({super.key, required this.store});
  final BrowserStore store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => FeatureScaffold(
      title: 'Search engines',
      actions: [
        IconButton(
          tooltip: 'Add engine',
          onPressed: () => _edit(context),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Choose a default engine. Custom search URLs must contain {query}. Use Meta search from the browser tools to search several engines at once.',
              style: TextStyle(color: Color(0xFF75828F), height: 1.6),
            ),
          ),
          ...store
              .rows('engines')
              .map(
                (engine) => Card(
                  child: ListTile(
                    leading: Icon(
                      engine['id'] == store.setting('engine', 'google')
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: const Color(0xFF087CFA),
                    ),
                    title: Text(engine['name'] as String),
                    subtitle: Text(
                      engine['url'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => store.setSetting('engine', engine['id']),
                    trailing: PopupMenuButton<String>(
                      popUpAnimationStyle: AppMotion.style,
                      onSelected: (value) {
                        if (value == 'edit') {
                          _edit(context, engine);
                        } else if (store.rows('engines').length > 1) {
                          store.remove('engines', engine['id'] as String);
                          if (store.setting('engine', 'google') ==
                              engine['id']) {
                            store.setSetting(
                              'engine',
                              store.rows('engines').first['id'],
                            );
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        if (store.rows('engines').length > 1)
                          const PopupMenuItem(
                            value: 'remove',
                            child: Text('Remove'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    ),
  );
  Future<void> _edit(BuildContext context, [Map<String, dynamic>? old]) async {
    final name = TextEditingController(text: old?['name'] as String? ?? ''),
        url = TextEditingController(
          text:
              old?['url'] as String? ?? 'https://example.com/search?q={query}',
        );
    await showCrockDialog<void>(
      context: context,
      builder: (context) => CrockEditorDialog(
        title: old == null ? 'Add search engine' : 'Edit search engine',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CrockEditorField(
              label: 'Engine name',
              controller: name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              hintText: 'e.g. Google',
            ),
            const SizedBox(height: 16),
            CrockEditorField(
              label: 'Search URL with {query}',
              controller: url,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              hintText: 'https://example.com/search?q={query}',
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
              final uri = Uri.tryParse(url.text.replaceAll('{query}', 'croc'));
              if (name.text.trim().isEmpty ||
                  !url.text.contains('{query}') ||
                  uri == null ||
                  !['http', 'https'].contains(uri.scheme) ||
                  uri.host.isEmpty) {
                crockMessage(
                  context,
                  'Enter a name and a valid search URL containing {query}',
                );
                return;
              }
              store.add('engines', {
                'id':
                    old?['id'] ??
                    DateTime.now().microsecondsSinceEpoch.toString(),
                'name': name.text.trim(),
                'url': url.text.trim(),
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    name.dispose();
    url.dispose();
  }
}
