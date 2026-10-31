import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/platform/native_bridge.dart';
import '../../shared/widgets/feature_scaffold.dart';

/// One encrypted contact profile, filled into a page only after an explicit action.
class AutofillProfileScreen extends StatefulWidget {
  const AutofillProfileScreen({super.key});
  @override
  State<AutofillProfileScreen> createState() => _AutofillProfileScreenState();
}

class _AutofillProfileScreenState extends State<AutofillProfileScreen> {
  static const fields = {
    'name': 'Full name',
    'email': 'Email',
    'tel': 'Phone',
    'street-address': 'Street address',
    'address-level2': 'City',
    'address-level1': 'State / region',
    'postal-code': 'Postal code',
    'country-name': 'Country',
    'organization': 'Organization',
  };
  final controllers = {
    for (final key in fields.keys) key: TextEditingController(),
  };
  bool unlocked = false, busy = false;
  Timer? expiry;
  Future<void> _unlock() async {
    setState(() => busy = true);
    try {
      if (await NativeBridge.instance.call<bool>('vault.unlock') == true) {
        final rows = await NativeBridge.instance.list('profiles.list');
        if (!mounted) return;
        if (rows.isNotEmpty) {
          for (final key in fields.keys) {
            controllers[key]!.text = rows.first[key]?.toString() ?? '';
          }
        }
        unlocked = true;
        expiry?.cancel();
        expiry = Timer(const Duration(minutes: 5), () {
          NativeBridge.instance.call('vault.lock');
          if (!mounted) return;
          for (final controller in controllers.values) {
            controller.clear();
          }
          setState(() => unlocked = false);
        });
      }
    } catch (error) {
      if (mounted) crockMessage(context, error);
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _save() async {
    try {
      await NativeBridge.instance.call('profiles.save', {
        'id': 'contact-profile',
        for (final entry in controllers.entries)
          entry.key: entry.value.text.trim(),
      });
      if (mounted) {
        crockMessage(context, 'Contact profile saved on this device');
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) crockMessage(context, error);
    }
  }

  @override
  void dispose() {
    expiry?.cancel();
    for (final controller in controllers.values) {
      controller.dispose();
    }
    NativeBridge.instance.call('vault.lock');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FeatureScaffold(
    title: 'Autofill profile',
    child: !unlocked
        ? CrockEmpty(
            title: 'Your details stay on this device',
            detail: 'Unlock with your Android screen lock to edit this encrypted contact profile.',
            action: FilledButton(
              onPressed: busy ? null : _unlock,
              child: Text(busy ? 'Unlocking…' : 'Unlock'),
            ),
          )
        : ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            children: [
              const Text(
                'Use Browser tools → Fill contact details on a page. Review the fields before submitting the website form.',
              ),
              const SizedBox(height: 16),
              for (final entry in fields.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TextField(
                    controller: controllers[entry.key],
                    keyboardType: entry.key == 'email'
                        ? TextInputType.emailAddress
                        : entry.key == 'tel'
                        ? TextInputType.phone
                        : TextInputType.text,
                    decoration: InputDecoration(labelText: entry.value),
                  ),
                ),
              FilledButton(onPressed: _save, child: const Text('Save profile')),
              TextButton(
                onPressed: () async {
                  await NativeBridge.instance.call('profiles.delete', {
                    'id': 'contact-profile',
                  });
                  if (context.mounted) Navigator.pop(context);
                },
                child: const Text('Delete saved profile'),
              ),
            ],
          ),
  );
}
