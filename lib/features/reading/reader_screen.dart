import '../../shared/widgets/crock_dropdown.dart';

import 'package:flutter/material.dart';

import '../../core/platform/native_bridge.dart';
import '../../core/storage/browser_store.dart';
import '../../shared/widgets/feature_scaffold.dart';

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.article, required this.store});
  final Map<String, dynamic> article;
  final BrowserStore store;
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late String text = widget.article['text'] as String? ?? '';
  String source = 'en', target = 'hi';
  bool busy = false;
  static const languages = {
    'en': 'English',
    'hi': 'Hindi',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'ar': 'Arabic',
    'bn': 'Bengali',
    'gu': 'Gujarati',
    'ta': 'Tamil',
    'te': 'Telugu',
    'mr': 'Marathi',
    'kn': 'Kannada',
    'ja': 'Japanese',
    'ko': 'Korean',
    'zh': 'Chinese',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'id': 'Indonesian',
    'it': 'Italian',
    'tr': 'Turkish',
    'vi': 'Vietnamese',
    'th': 'Thai',
    'ur': 'Urdu',
  };
  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'Reader',
    actions: [
      IconButton(
        tooltip: 'Translate text',
        onPressed: _translateOptions,
        icon: const Icon(Icons.translate_rounded),
      ),
      IconButton(
        tooltip: 'Export text',
        onPressed: () async {
          try {
            await NativeBridge.instance.call('files.exportText', {
              'name': '${widget.article['title'] ?? 'Crock article'}.txt',
              'mime': 'text/plain',
              'text': text,
            });
          } catch (e) {
            if (context.mounted) crockMessage(context, e);
          }
        },
        icon: const Icon(Icons.save_alt_rounded),
      ),
    ],
    child: Column(
      children: [
        if (busy) const LinearProgressIndicator(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 8, 26, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.article['title'] as String? ?? 'Reader',
                  style: const TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  Uri.tryParse(widget.article['url'] as String? ?? '')?.host ??
                      '',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const Divider(height: 40),
                SelectableText(
                  text,
                  style: TextStyle(
                    fontSize:
                        18 * (widget.store.setting('font', 100) as num) / 100,
                    height: 1.8,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
  Future<void> _translateOptions() async {
    await showCrockDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => CrockDialog(
          title: const Text('Translate on device'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'The selected language models download on first use. Text is translated on this device.',
              ),
              const SizedBox(height: 18),
              CrockDropdownButtonFormField<String>(
                initialValue: source,
                decoration: const InputDecoration(labelText: 'From'),
                items: languages.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() => source = v ?? 'en'),
              ),
              const SizedBox(height: 12),
              CrockDropdownButtonFormField<String>(
                initialValue: target,
                decoration: const InputDecoration(labelText: 'To'),
                items: languages.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() => target = v ?? 'hi'),
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
                Navigator.pop(context);
                _translate();
              },
              child: const Text('Translate'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _translate() async {
    setState(() => busy = true);
    try {
      final translated = await NativeBridge.instance.call<String>('translate', {
        'text': text,
        'source': source,
        'target': target,
      });
      if (translated != null && mounted) setState(() => text = translated);
    } catch (error) {
      if (mounted) crockMessage(context, error);
    }
    if (mounted) setState(() => busy = false);
  }
}
