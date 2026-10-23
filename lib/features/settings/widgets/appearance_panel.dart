import 'package:flutter/material.dart';

import '../../../core/platform/native_bridge.dart';
import '../../../core/theme/crock_theme.dart';
import '../../../shared/widgets/feature_scaffold.dart';
import '../../browser/browser_controller.dart';
import 'settings_components.dart';

class AppearancePanel extends StatelessWidget {
  const AppearancePanel({super.key, required this.browser});
  final BrowserController browser;
  static const rotations = {
    'auto': (
      'Follow device',
      'Use your device rotation setting',
      Icons.screen_rotation_rounded,
    ),
    'portrait': (
      'Portrait',
      'Keep the screen upright',
      Icons.stay_current_portrait_rounded,
    ),
    'landscape': (
      'Landscape',
      'Use a wider view',
      Icons.stay_current_landscape_rounded,
    ),
  };

  Future<void> _device(BuildContext context, String key, Object value) async {
    try {
      await NativeBridge.instance.call('device.$key', {'value': value});
      browser.store.setSetting(key, value);
    } catch (error) {
      if (context.mounted) crockMessage(context, error);
    }
  }

  Future<void> _rotation(BuildContext context) async {
    final selected = browser.store.setting('rotation', 'auto');
    final value = await showCrockSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Screen orientation',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose the view that feels right.',
              style: TextStyle(color: CrockTheme.muted),
            ),
            const SizedBox(height: 22),
            for (final choice in rotations.entries) ...[
              Material(
                color: selected == choice.key
                    ? const Color(0xFFF0F7FF)
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: selected == choice.key
                        ? CrockTheme.blue
                        : CrockTheme.line,
                  ),
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Icon(
                    choice.value.$3,
                    color: selected == choice.key
                        ? CrockTheme.blue
                        : CrockTheme.muted,
                  ),
                  title: Text(
                    choice.value.$1,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    choice.value.$2,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: Icon(
                    selected == choice.key
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected == choice.key
                        ? CrockTheme.blue
                        : CrockTheme.line,
                  ),
                  onTap: () => Navigator.pop(context, choice.key),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
    if (value != null && context.mounted) {
      await _device(context, 'rotation', value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = browser.store;
    final font = (store.setting('font', 100) as num).clamp(70, 200).toDouble();
    final brightness = (store.setting('brightness', -1) as num).toDouble();
    final system = brightness < 0;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          child: Column(
            children: [
              Row(
                children: [
                  const SettingsIcon(Icons.text_fields_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Text size',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  _value('${font.round()}%'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text(
                    'A',
                    style: TextStyle(fontSize: 13, color: CrockTheme.muted),
                  ),
                  Expanded(
                    child: Slider(
                      min: 70,
                      max: 200,
                      value: font,
                      label: '${font.round()}%',
                      onChanged: (value) {
                        store.setSetting('font', value.round());
                        browser.updateSettings();
                      },
                    ),
                  ),
                  const Text(
                    'A',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w600,
                      color: CrockTheme.muted,
                    ),
                  ),
                ],
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F9FE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'A little curiosity.\nA whole wide web.',
                  style: TextStyle(
                    fontSize: 14 * font / 100,
                    height: 1.5,
                    color: CrockTheme.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(indent: 18, endIndent: 18),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
          child: Column(
            children: [
              Row(
                children: [
                  const SettingsIcon(Icons.brightness_6_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Brightness',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  _value(system ? 'Auto' : '${(brightness * 100).round()}%'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.brightness_low_rounded,
                    size: 18,
                    color: CrockTheme.muted,
                  ),
                  Expanded(
                    child: Slider(
                      min: .05,
                      max: 1,
                      value: system ? .5 : brightness.clamp(.05, 1),
                      onChanged: system
                          ? null
                          : (value) => _device(context, 'brightness', value),
                    ),
                  ),
                  const Icon(
                    Icons.brightness_high_rounded,
                    size: 22,
                    color: CrockTheme.muted,
                  ),
                ],
              ),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Match device brightness',
                      style: TextStyle(fontSize: 13, color: CrockTheme.muted),
                    ),
                  ),
                  Switch(
                    value: system,
                    onChanged: (value) =>
                        _device(context, 'brightness', value ? -1 : .5),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(indent: 18, endIndent: 18),
        SettingsRow(
          icon: Icons.screen_rotation_rounded,
          title: 'Screen orientation',
          subtitle:
              rotations[store.setting('rotation', 'auto')]?.$1 ??
              'Follow device',
          onTap: () => _rotation(context),
        ),
      ],
    );
  }

  Widget _value(String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF3FF),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: CrockTheme.blue,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
