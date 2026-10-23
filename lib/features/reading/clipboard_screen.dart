import 'package:flutter/material.dart';

import '../../core/platform/native_bridge.dart';
import '../../core/storage/browser_store.dart';
import '../../shared/widgets/feature_scaffold.dart';

class ClipboardScreen extends StatelessWidget {
  const ClipboardScreen({super.key, required this.store, required this.onOpen});
  final BrowserStore store;
  final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => FeatureScaffold(
      title: 'Clipboard manager',
      actions: [
        IconButton(
          tooltip: 'Save current clipboard',
          onPressed: () async {
            try {
              final text = await NativeBridge.instance.call<String>(
                'clipboard.read',
              );
              if (text != null && text.isNotEmpty) {
                store.add('clips', {
                  'id': DateTime.now().microsecondsSinceEpoch.toString(),
                  'text': text,
                }, limit: 100);
              }
            } catch (error) {
              if (context.mounted) crockMessage(context, error);
            }
          },
          icon: const Icon(Icons.add_rounded),
        ),
      ],
      child: store.rows('clips').isEmpty
          ? const CrockEmpty(
              title: 'Keep useful snippets',
              detail: 'Tap + to explicitly save the current clipboard. Crock Browser does not monitor the clipboard in the background.',
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: store
                  .rows('clips')
                  .map(
                    (clip) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SelectableText(clip['text'] as String, maxLines: 8),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  tooltip: 'Open or search',
                                  onPressed: () {
                                    Navigator.pop(context);
                                    onOpen(clip['text'] as String);
                                  },
                                  icon: const Icon(
                                    Icons.open_in_browser_rounded,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Copy',
                                  onPressed: () => NativeBridge.instance.call(
                                    'clipboard.write',
                                    {'text': clip['text']},
                                  ),
                                  icon: const Icon(Icons.copy_rounded),
                                ),
                                IconButton(
                                  tooltip: 'Remove',
                                  onPressed: () => store.remove(
                                    'clips',
                                    clip['id'] as String,
                                  ),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    ),
  );
}
