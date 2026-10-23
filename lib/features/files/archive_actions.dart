import 'package:flutter/material.dart';

import '../../core/platform/native_bridge.dart';
import '../../shared/widgets/feature_scaffold.dart';

bool isSupportedArchive(String name) =>
    RegExp(r'\.(zip|rar|7z)$', caseSensitive: false).hasMatch(name);

Future<String?> extractArchive(
  BuildContext context,
  Map<String, dynamic> file,
) => showCrockDialog<String>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _ExtractDialog(file: file),
);

class _ExtractDialog extends StatefulWidget {
  const _ExtractDialog({required this.file});
  final Map<String, dynamic> file;
  @override
  State<_ExtractDialog> createState() => _ExtractDialogState();
}

class _ExtractDialogState extends State<_ExtractDialog> {
  final password = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  Future<void> extract() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final folder = await NativeBridge.instance.call<String>('files.extract', {
        'path': widget.file['path'],
        'password': password.text,
      });
      if (mounted) dismissCrockRoute<String>(context, folder);
    } catch (failure) {
      if (mounted) {
        setState(() {
          busy = false;
          error = failure.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('Extract archive'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.file['name']?.toString() ?? 'Archive'),
            const SizedBox(height: 12),
            const Text(
              'Files are saved to a new folder in Crock downloads. Keep the app open until extraction finishes.',
            ),
            if (!widget.file['name'].toString().toLowerCase().endsWith(
              '.zip',
            )) ...[
              const SizedBox(height: 16),
              TextField(
                controller: password,
                enabled: !busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Password (if required)',
                ),
                onSubmitted: (_) {
                  if (!busy) extract();
                },
              ),
            ],
            if (busy) ...[
              const SizedBox(height: 20),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Text('Extracting…'),
            ],
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy ? null : extract,
          child: const Text('Extract'),
        ),
      ],
    ),
  );
}
