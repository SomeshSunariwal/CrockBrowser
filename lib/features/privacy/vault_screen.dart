import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/platform/native_bridge.dart';
import '../../shared/widgets/feature_scaffold.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key, this.passwords = false});
  final bool passwords;
  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  bool unlocked = false, busy = false;
  List<Map<String, dynamic>> rows = [];
  String? error;
  Timer? expiry;
  @override
  void dispose() {
    expiry?.cancel();
    NativeBridge.instance.call('vault.lock');
    super.dispose();
  }

  Future<void> _unlock() async {
    setState(() => busy = true);
    try {
      final ok = await NativeBridge.instance.call<bool>('vault.unlock');
      if (ok == true) {
        rows = await NativeBridge.instance.list(
          widget.passwords ? 'passwords.list' : 'vault.list',
        );
        unlocked = true;
        expiry?.cancel();
        expiry = Timer(const Duration(minutes: 5), () {
          NativeBridge.instance.call('vault.lock');
          if (mounted) {
            setState(() {
              unlocked = false;
              rows = [];
            });
          }
        });
      }
      error = null;
    } catch (e) {
      error = e.toString();
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: widget.passwords ? 'Saved passwords' : 'Private Space',
    actions: [
      if (unlocked)
        IconButton(
          tooltip: 'Lock',
          onPressed: () async {
            await NativeBridge.instance.call('vault.lock');
            setState(() {
              unlocked = false;
              rows = [];
            });
          },
          icon: const Icon(Icons.lock_outline_rounded),
        ),
    ],
    child: busy
        ? const Center(child: CircularProgressIndicator())
        : !unlocked
        ? CrockEmpty(
            title: widget.passwords
                ? 'Your logins, protected'
                : 'A private place for your files',
            detail: error ?? 'Stored locally with Android Keystore encryption. Unlock with your device screen lock.',
            action: FilledButton.icon(
              onPressed: _unlock,
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Unlock'),
            ),
          )
        : rows.isEmpty
        ? CrockEmpty(
            title: 'Nothing stored yet',
            detail: widget.passwords
                ? 'Use Save login from a webpage to store a login after device authentication.'
                : 'Use Copy to Private Space from a file’s menu to add an encrypted copy.',
          )
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              return Card(
                child: ListTile(
                  leading: Icon(
                    widget.passwords ? Icons.key_rounded : Icons.lock_outline,
                    color: const Color(0xFF087CFA),
                  ),
                  title: Text(
                    (widget.passwords ? row['origin'] : row['name'])
                            as String? ??
                        'Saved item',
                  ),
                  subtitle: Text(
                    widget.passwords
                        ? row['username'] as String? ?? ''
                        : byteLabel(row['size'] as num? ?? 0),
                  ),
                  onTap: () async {
                    try {
                      if (!widget.passwords) {
                        await NativeBridge.instance.call('vault.open', {
                          'id': row['id'],
                        });
                      } else {
                        await showCrockDialog<void>(
                          context: context,
                          builder: (context) => CrockDialog(
                            title: Text(
                              row['origin'] as String? ?? 'Saved login',
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SelectableText('Username: ${row['username']}'),
                                const SizedBox(height: 12),
                                SelectableText('Password: ${row['password']}'),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) crockMessage(context, e);
                    }
                  },
                  trailing: IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () async {
                      if (!await confirmCrock(
                        context,
                        'Delete saved item?',
                        'This cannot be undone.',
                      )) {
                        return;
                      }
                      try {
                        await NativeBridge.instance.call(
                          widget.passwords
                              ? 'passwords.delete'
                              : 'vault.delete',
                          {'id': row['id']},
                        );
                        rows = await NativeBridge.instance.list(
                          widget.passwords ? 'passwords.list' : 'vault.list',
                        );
                        if (mounted) setState(() {});
                      } catch (e) {
                        if (context.mounted) crockMessage(context, e);
                      }
                    },
                  ),
                ),
              );
            },
          ),
  );
}
