import 'package:flutter/material.dart';

import '../../core/platform/native_bridge.dart';
import '../../core/storage/browser_store.dart';
import '../../core/theme/crock_theme.dart';
import '../../shared/widgets/crock_logo.dart';
import '../../shared/widgets/feature_scaffold.dart';
import '../browser/browser_controller.dart';
import '../home/shortcuts_screen.dart';
import 'search_engines_screen.dart';
import 'widgets/appearance_panel.dart';
import 'widgets/settings_components.dart';

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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE8F4FF), Color(0xFFEDFBFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFFDCEFFF)),
            ),
            child: Row(
              children: [
                const CrockLogo(size: 58),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Make it yours.',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'A better view of your web.',
                        style: TextStyle(fontSize: 12, color: CrockTheme.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SettingsSection(
            title: 'Home & search',
            children: [
              SettingsRow(
                icon: Icons.search_rounded,
                title: 'Search engines',
                subtitle: 'Choose how you explore',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => SearchEnginesScreen(store: store),
                  ),
                ),
              ),
              SettingsRow(
                icon: Icons.grid_view_rounded,
                title: 'Home shortcuts',
                subtitle: 'Keep your favourites close',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ShortcutsScreen(store: store),
                  ),
                ),
              ),
            ],
          ),
          SettingsSection(
            title: 'Reading & display',
            children: [AppearancePanel(browser: browser)],
          ),
          SettingsSection(
            title: 'Tabs & privacy',
            children: [
              SettingsRow(
                icon: Icons.password_rounded,
                title: 'Offer to save passwords',
                subtitle: 'Ask after successful sign-ins in regular tabs',
                trailing: Switch(
                  value: store.setting('offerSavePasswords', true) == true,
                  onChanged: (value) async {
                    store.setSetting('offerSavePasswords', value);
                    await browser.updateSettings();
                  },
                ),
              ),
              if ((store.setting(
                'passwordPromptBlockedOrigins',
                const <String>[],
              ) as List).isNotEmpty)
                SettingsRow(
                  icon: Icons.lock_reset_rounded,
                  title: 'Reset password-save exclusions',
                  subtitle: 'Allow prompts on sites you excluded',
                  onTap: () async {
                    if (!await confirmCrock(
                      context,
                      'Reset excluded sites?',
                      'The browser can offer to save passwords on these sites again.',
                    )) {
                      return;
                    }
                    store.setSetting(
                      'passwordPromptBlockedOrigins',
                      <String>[],
                    );
                    await browser.updateSettings();
                  },
                ),
              SettingsRow(
                icon: Icons.restore_page_outlined,
                title: 'Pick up where you left off',
                subtitle: 'Restore regular tabs on launch',
                trailing: Switch(
                  value: store.setting('restoreTabs', true) == true,
                  onChanged: (value) => store.setSetting('restoreTabs', value),
                ),
              ),
              SettingsRow(
                icon: Icons.grid_view_rounded,
                title: 'Tab grid',
                subtitle: 'See your tabs at a glance',
                trailing: Switch(
                  value: store.setting('tabGrid', true) == true,
                  onChanged: (value) => store.setSetting('tabGrid', value),
                ),
              ),
              SettingsRow(
                icon: Icons.history_rounded,
                title: 'Clear browsing history',
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
              SettingsRow(
                icon: Icons.cookie_outlined,
                title: 'Clear website data',
                subtitle: 'Cookies, cache and local storage',
                onTap: () async {
                  if (await confirmCrock(
                    context,
                    'Clear site data?',
                    'You will be signed out of websites. Bookmarks and downloads are kept.',
                  )) {
                    if (context.mounted) {
                      await _call(context, 'browser.clearData');
                    }
                  }
                },
              ),
            ],
          ),
          SettingsSection(
            title: 'Cleaner browsing',
            children: [
              SettingsRow(
                icon: Icons.shield_outlined,
                title: 'Ad blocking',
                subtitle: 'Filter known advertising hosts',
                trailing: Switch(
                  value: store.setting('adBlock', false) == true,
                  onChanged: (value) {
                    store.setSetting('adBlock', value);
                    browser.updateSettings();
                  },
                ),
              ),
              SettingsRow(
                icon: Icons.layers_clear_outlined,
                title: 'Reset hidden elements',
                subtitle: 'Show items you manually hid',
                onTap: () => _call(context, 'blocking.clear'),
              ),
            ],
          ),
          const SizedBox(height: 30),
          const Center(
            child: Text(
              'Crock Browser 1.0',
              style: TextStyle(fontSize: 12, color: CrockTheme.muted),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'Your bookmarks and files stay on your device.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: CrockTheme.muted),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _call(BuildContext context, String method) async {
    try {
      await NativeBridge.instance.call(method);
    } catch (error) {
      if (context.mounted) crockMessage(context, error);
    }
  }
}
