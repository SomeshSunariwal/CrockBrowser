import 'package:flutter/material.dart';

import '../../core/platform/native_bridge.dart';
import '../../core/storage/browser_store.dart';
import '../../shared/widgets/crock_logo.dart';
import '../../shared/widgets/feature_scaffold.dart';
import '../browser/browser_controller.dart';
import 'search_engines_screen.dart';
import '../home/shortcuts_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.browser});
  final BrowserController browser;
  BrowserStore get store => browser.store;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => FeatureScaffold(
      title: 'Settings',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const CrockLogo(size: 50),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Crock Browser',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Local-first. Built for curiosity.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8796A6),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _heading('HOME & SEARCH'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.search_rounded),
                  title: const Text('Search engines'),
                  subtitle: const Text('Choose, add and edit engines'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => SearchEnginesScreen(store: store),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.grid_view_rounded),
                  title: const Text('Manage home shortcuts'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => ShortcutsScreen(store: store),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _heading('DISPLAY'),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Webpage and reader font size'),
                    trailing: Text('${store.setting('font', 100)}%'),
                  ),
                  Slider(
                    min: 70,
                    max: 200,
                    divisions: 26,
                    value: (store.setting('font', 100) as num).toDouble(),
                    onChanged: (value) {
                      store.setSetting('font', value.round());
                      browser.updateSettings();
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('App brightness'),
                    trailing: Text(
                      store.setting('brightness', -1) == -1
                          ? 'System'
                          : '${((store.setting('brightness', .5) as num) * 100).round()}%',
                    ),
                  ),
                  Slider(
                    min: .05,
                    max: 1,
                    divisions: 19,
                    value: (store.setting('brightness', .5) as num)
                        .toDouble()
                        .clamp(.05, 1),
                    onChanged: (value) async {
                      store.setSetting('brightness', value);
                      await _call(context, 'device.brightness', {
                        'value': value,
                      });
                    },
                  ),
                  TextButton(
                    onPressed: () {
                      store.setSetting('brightness', -1);
                      _call(context, 'device.brightness', {'value': -1});
                    },
                    child: const Text('Use system brightness'),
                  ),
                  const Divider(),
                  DropdownButtonFormField<String>(
                    initialValue: store.setting('rotation', 'auto') as String,
                    decoration: const InputDecoration(
                      labelText: 'Screen rotation',
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'auto',
                        child: Text('Follow device rotation'),
                      ),
                      DropdownMenuItem(
                        value: 'portrait',
                        child: Text('Portrait'),
                      ),
                      DropdownMenuItem(
                        value: 'landscape',
                        child: Text('Landscape'),
                      ),
                    ],
                    onChanged: (value) {
                      store.setSetting('rotation', value);
                      _call(context, 'device.rotation', {'value': value});
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          _heading('TABS & PRIVACY'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Restore normal tabs on launch'),
                  subtitle: const Text('Private tabs are never saved.'),
                  value: store.setting('restoreTabs', true) == true,
                  onChanged: (value) => store.setSetting('restoreTabs', value),
                ),
                SwitchListTile(
                  title: const Text('Grid tab switcher'),
                  value: store.setting('tabGrid', true) == true,
                  onChanged: (value) => store.setSetting('tabGrid', value),
                ),
                ListTile(
                  title: const Text('Clear browsing history'),
                  leading: const Icon(Icons.history_rounded),
                  onTap: () async {
                    if (await confirmCrock(
                      context,
                      'Clear history?',
                      'Remove saved normal browsing history?',
                    )) {
                      store.setRows('history', []);
                    }
                  },
                ),
                ListTile(
                  title: const Text('Clear cookies and website storage'),
                  leading: const Icon(Icons.delete_sweep_outlined),
                  onTap: () async {
                    if (await confirmCrock(
                      context,
                      'Clear site data?',
                      'You will be signed out of websites. Bookmarks and downloads are kept.',
                    )) {
                      if (!context.mounted) return;
                      await _call(context, 'browser.clearData', {});
                    }
                  },
                ),
              ],
            ),
          ),
          _heading('AD BLOCKING'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Block known ad hosts'),
                  subtitle: const Text(
                    'Basic host filtering. Some ads may still appear.',
                  ),
                  value: store.setting('adBlock', false) == true,
                  onChanged: (value) {
                    store.setSetting('adBlock', value);
                    browser.updateSettings();
                  },
                ),
                ListTile(
                  title: const Text('Reset manually hidden elements'),
                  leading: const Icon(Icons.restore_rounded),
                  onTap: () => _call(context, 'blocking.clear', {}),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'Crock Browser 1.0 · Flutter + Java\nNo cloud backup or account required.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF8796A6),
                height: 1.7,
              ),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 24, 0, 10),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
        color: Color(0xFF8796A6),
      ),
    ),
  );
  Future<void> _call(
    BuildContext context,
    String method,
    Map<String, dynamic> args,
  ) async {
    try {
      await NativeBridge.instance.call(method, args);
    } catch (error) {
      if (context.mounted) crockMessage(context, error);
    }
  }
}
