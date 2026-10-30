import '../../../shared/widgets/gradient_slider.dart';

import 'package:flutter/material.dart';

import '../../../core/platform/native_bridge.dart';
import '../../../shared/widgets/feature_scaffold.dart';
import '../../browser/browser_controller.dart';
import 'settings_components.dart';

class AppearancePanel extends StatefulWidget {
  const AppearancePanel({super.key, required this.browser});
  final BrowserController browser;
  static const rotations = {
    'auto': ('Follow device', Icons.screen_rotation_rounded),
    'portrait': ('Portrait', Icons.stay_current_portrait_rounded),
    'landscape': ('Landscape', Icons.stay_current_landscape_rounded),
  };

  @override
  State<AppearancePanel> createState() => _AppearancePanelState();
}

class _AppearancePanelState extends State<AppearancePanel> {
  BrowserController get browser => widget.browser;
  static const rotations = AppearancePanel.rotations;
  bool _textExpanded = false, _brightnessExpanded = false;

  Future<void> _device(BuildContext context, String key, Object value) async {
    try {
      await NativeBridge.instance.call('device.$key', {'value': value});
      browser.store.setSetting(key, value);
    } catch (error) {
      if (context.mounted) crockMessage(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = browser.store;
    final font = (store.setting('font', 100) as num).clamp(70, 200).toDouble();
    final brightness = (store.setting('brightness', -1) as num).toDouble();
    final savedTheme = store.setting(
      'themeMode',
      store.setting('darkTheme', false) == true ? 'dark' : 'system',
    ) as String;
    final rows = <Widget>[
      SettingsRow(
        icon: Icons.web_asset_rounded,
        title: 'Address Bar',
        subtitle: 'Keep visible or hide while scrolling down',
        trailing: SettingsDropdown(
          value: store.setting('addressBarMode', 'static') as String,
          options: const {'static': 'Static', 'dynamic': 'Dynamic'},
          onChanged: (value) => store.setSetting('addressBarMode', value),
        ),
      ),
      SettingsRow(
        icon: Icons.dark_mode_outlined,
        title: 'Theme',
        subtitle: 'Choose how the browser looks',
        trailing: SettingsDropdown(
          value: savedTheme,
          options: const {'system': 'System', 'dark': 'Dark', 'light': 'Light'},
          icons: const {
            'system': Icons.brightness_auto_rounded,
            'dark': Icons.dark_mode_outlined,
            'light': Icons.light_mode_outlined,
          },
          onChanged: (value) async {
            store.setSetting('themeMode', value);
            store.setSetting('darkTheme', value == 'dark');
            await browser.updateSettings();
          },
        ),
      ),
      Column(
        children: [
          SettingsRow(
            icon: Icons.text_fields_rounded,
            title: 'Text size',
            subtitle: 'Adjust webpage text size',
            trailing: Icon(
              _textExpanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onTap: () => setState(() => _textExpanded = !_textExpanded),
          ),
          if (_textExpanded)
            _sliderRow(
              context,
              slider: Slider(
                key: const ValueKey('text-size-slider'),
                min: 70,
                max: 200,
                value: font,
                label: '${font.round()}%',
                onChanged: (value) {
                  store.setSetting('font', value.round());
                  setState(() {});
                  browser.updateSettings();
                },
              ),
              percentage: '${font.round()}%',
              action: 'Reset',
              onAction: () {
                store.setSetting('font', 100);
                setState(() {});
                browser.updateSettings();
              },
            ),
        ],
      ),
      Column(
        children: [
          SettingsRow(
            icon: Icons.brightness_6_outlined,
            title: 'Brightness',
            subtitle: 'Auto or custom screen brightness',
            trailing: Icon(
              _brightnessExpanded
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onTap: () =>
                setState(() => _brightnessExpanded = !_brightnessExpanded),
          ),
          if (_brightnessExpanded)
            _sliderRow(
              context,
              slider: Slider(
                key: const ValueKey('brightness-slider'),
                min: .05,
                max: 1,
                value: brightness < 0 ? .5 : brightness.clamp(.05, 1),
                onChanged: (value) => _setBrightness(context, value),
              ),
              percentage: brightness < 0
                  ? 'Auto'
                  : '${(brightness * 100).round()}%',
              action: 'Auto',
              actionSelected: brightness < 0,
              onAction: () => _setBrightness(context, -1),
            ),
        ],
      ),
      SettingsRow(
        icon: Icons.screen_rotation_rounded,
        title: 'Screen orientation',
        subtitle: 'Choose the screen orientation',
        trailing: SettingsDropdown(
          value: store.setting('rotation', 'auto') as String,
          options: {
            for (final entry in rotations.entries) entry.key: entry.value.$1,
          },
          icons: {
            for (final entry in rotations.entries) entry.key: entry.value.$2,
          },
          onChanged: (value) => _device(context, 'rotation', value),
        ),
      ),
    ];
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(indent: 56, endIndent: 12),
          rows[i],
        ],
      ],
    );
  }

  Widget _sliderRow(
    BuildContext context, {
    required Widget slider,
    required String percentage,
    required String action,
    required VoidCallback onAction,
    bool actionSelected = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 0, 12, 10),
      child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 8,
          activeTrackColor: colors.primary,
          inactiveTrackColor: colors.onSurface.withValues(alpha: .18),
          thumbColor: Colors.white,
          overlayColor: colors.primary.withValues(alpha: .08),
          thumbShape: const ThemeSliderThumb(),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          trackShape: ThemeGradientSliderTrack(
            start: colors.primary,
            end: colors.secondary,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
        ),
        child: SizedBox(
          height: 40,
          child: Row(
            children: [
              Expanded(child: slider),
              SizedBox(
                width: 44,
                child: Text(
                  percentage,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(56, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: colors.primary,
                  backgroundColor: actionSelected
                      ? colors.primary.withValues(alpha: .08)
                      : Colors.transparent,
                  side: BorderSide(
                    color: colors.primary.withValues(alpha: .35),
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Text(action),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _setBrightness(BuildContext context, double value) async {
    await _device(context, 'brightness', value);
    if (mounted) setState(() {});
  }
}
