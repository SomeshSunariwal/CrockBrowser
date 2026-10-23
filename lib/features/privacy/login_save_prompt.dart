import 'package:flutter/material.dart';

import '../../core/platform/native_bridge.dart';
import '../../core/storage/browser_store.dart';
import '../../shared/widgets/crock_logo.dart';
import '../../shared/widgets/feature_scaffold.dart';

/// Consent and device authentication are required before storing a detected login.
class LoginSavePrompt {
  LoginSavePrompt(this.store);
  final BrowserStore store;
  bool _showing = false;

  Future<void> offer(
    BuildContext context,
    Map<String, dynamic> candidate, {
    required bool Function() isCurrent,
    required Future<void> Function() updateSettings,
  }) async {
    if (_showing ||
        store.privateMode ||
        store.setting('offerSavePasswords', true) != true) {
      return;
    }
    final origin = candidate['origin']?.toString() ?? '';
    final username = candidate['username']?.toString() ?? '';
    final password = candidate['password']?.toString() ?? '';
    final excluded = List<String>.from(
      store.setting('passwordPromptBlockedOrigins', const <String>[]) as List,
    );
    if (origin.isEmpty ||
        password.isEmpty ||
        excluded.contains(origin) ||
        !isCurrent()) {
      return;
    }
    _showing = true;
    bool unlocked = false;
    try {
      final credentials = {
        'origin': origin,
        'username': username,
        'password': password,
      };
      final status = await NativeBridge.instance.call<Map>(
        'passwords.status',
        credentials,
      );
      if (status?['matches'] == true || !context.mounted || !isCurrent()) {
        return;
      }
      final updating = status?['exists'] == true;
      final choice = await showCrockDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const CrockLogo(size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(updating ? 'Update password?' : 'Save password?'),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(origin, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (username.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(username, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 16),
              const Text(
                'Save securely on this device with your screen lock. Your password will not be saved unless you confirm.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'never'),
              child: const Text('Never for this site'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, 'save'),
              child: Text(updating ? 'Update' : 'Save'),
            ),
          ],
        ),
      );
      if (choice == 'never') {
        store.setSetting('passwordPromptBlockedOrigins', [...excluded, origin]);
        await store.flush();
        await updateSettings();
        return;
      }
      if (choice != 'save' || !isCurrent()) return;
      unlocked = await NativeBridge.instance.call<bool>('vault.unlock') == true;
      if (!unlocked || !isCurrent()) return;
      final saved = await NativeBridge.instance.list('passwords.list');
      final matching = saved
          .where(
            (row) => row['origin'] == origin && row['username'] == username,
          )
          .firstOrNull;
      await NativeBridge.instance.call('passwords.save', {
        ...?matching,
        ...credentials,
        'id':
            matching?['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
      });
      if (context.mounted) {
        crockMessage(
          context,
          updating
              ? 'Password updated on this device'
              : 'Password saved on this device',
        );
      }
    } catch (error) {
      if (context.mounted) crockMessage(context, error);
    } finally {
      try {
        if (unlocked) await NativeBridge.instance.call('vault.lock');
      } finally {
        candidate.remove('password');
        _showing = false;
      }
    }
  }
}
