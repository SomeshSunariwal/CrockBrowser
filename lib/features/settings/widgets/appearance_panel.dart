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
    final colors = Theme.of(context).colorScheme;
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
            Text(
              'Choose the view that feels right.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 22),
            for (final choice in rotations.entries) ...[
              Material(
                color: selected == choice.key
                    ? colors.primaryContainer
                    : colors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: BorderSide(
                    color: selected == choice.key
                        ? CrockTheme.blue
                        : colors.outlineVariant,
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
                        : colors.onSurfaceVariant,
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
                        : colors.outlineVariant,
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
    final colors = Theme.of(context).colorScheme;
    final savedTheme = store.setting(
      'themeMode',
      store.setting('darkTheme', false) == true ? 'dark' : 'system',
    ) as String;
    return Column(
      children: [
        SettingsRow(
          icon: Icons.dark_mode_outlined,
          title: 'Theme',
          subtitle: 'Choose how the browser looks',
          trailing: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: const {'system', 'dark', 'light'}.contains(savedTheme)
                  ? savedTheme
                  : 'system',
              isDense: true,
              borderRadius: BorderRadius.circular(14),
              items: const [
                DropdownMenuItem(value: 'system', child: Text('System Driven')),
                DropdownMenuItem(value: 'dark', child: Text('Dark')),
                DropdownMenuItem(value: 'light', child: Text('Light')),
              ],
              onChanged: (value) async {
                if (value == null) return;
                store.setSetting('themeMode', value);
                store.setSetting('darkTheme', value == 'dark');
                await browser.updateSettings();
              },
            ),
          ),
        ),
        const Divider(indent: 18, endIndent: 18),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
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
                  if (font.round() != 100) ...[
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        store.setSetting('font', 100);
                        browser.updateSettings();
                      },
                      child: const Text('Reset'),
                    ),
                    const SizedBox(width: 4),
                  ],
                  _value(context, '${font.round()}%'),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Text(
                    'A',
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.onSurfaceVariant,
                    ),
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
                  Text(
                    'A',
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w600,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'A little curiosity.\nA whole wide web.',
                  style: TextStyle(
                    fontSize: 14 * font / 100,
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(indent: 18, endIndent: 18),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
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
                  _value(
                    context,
                    system ? 'Auto' : '${(brightness * 100).round()}%',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.brightness_low_rounded,
                    size: 18,
                    color: colors.onSurfaceVariant,
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
                  Icon(
                    Icons.brightness_high_rounded,
                    size: 22,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Match device brightness',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
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

  Widget _value(BuildContext context, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
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
