import '../../shared/widgets/crock_switch.dart';

import 'package:flutter/material.dart';

import '../../core/platform/native_bridge.dart';
import '../../core/storage/browser_store.dart';
import 'widgets/profile_card.dart';
import '../../shared/widgets/feature_scaffold.dart';
import '../../shared/widgets/selected_builder.dart';
import '../browser/browser_controller.dart';
import '../home/shortcuts_screen.dart';
import '../library/library_screen.dart';
import '../privacy/browsing_data_time_range.dart';
import 'search_engines_screen.dart';
import 'widgets/appearance_panel.dart';
import 'widgets/settings_components.dart';
import 'widgets/clear_website_data_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.browser});
  final BrowserController browser;
  BrowserStore get store => browser.store;

  @override
  Widget build(BuildContext context) => SelectedBuilder<Object>(
    listenable: store,
    select: () => (
      store.setting('offerSavePasswords', true),
      store.setting('passwordPromptBlockedOrigins', const <String>[]),
      store.setting('restoreTabs', true),
      store.setting('tabGrid', true),
      store.setting('adBlock', true),
      browser.youtubeAutoSkipAds,
      store.setting('profileName', 'Your Browser'),
      store.setting('profilePhoto', ''),
    ),
    builder: (context, _) => FeatureScaffold(
      title: 'Settings',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          ProfileCard(store: store),
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
                trailing: CrockSwitch(
                  semanticLabel: 'Offer to save passwords',
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
                trailing: CrockSwitch(
                  semanticLabel: 'Restore tabs on launch',
                  value: store.setting('restoreTabs', true) == true,
                  onChanged: (value) => store.setSetting('restoreTabs', value),
                ),
              ),
              SettingsRow(
                icon: Icons.grid_view_rounded,
                title: 'Tab grid',
                subtitle: 'See your tabs at a glance',
                trailing: CrockSwitch(
                  semanticLabel: 'Tab grid',
                  value: store.setting('tabGrid', true) == true,
                  onChanged: (value) => store.setSetting('tabGrid', value),
                ),
              ),
              SettingsRow(
                icon: Icons.history_rounded,
                title: 'History',
                subtitle: 'View and manage visited pages',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => LibraryScreen(
                      store: store,
                      mode: 'history',
                      onOpen: (url) {
                        Navigator.of(context).pop();
                        browser.open(url);
                      },
                      onOffline: (item) {
                        Navigator.of(context).pop();
                        browser.openOffline(item);
                      },
                    ),
                  ),
                ),
              ),
              SettingsRow(
                icon: Icons.cookie_outlined,
                title: 'Clear website data',
                subtitle: 'Cookies, cache and local storage',
                onTap: () => _clearWebsiteData(context),
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
                trailing: CrockSwitch(
                  semanticLabel: 'Ad blocking',
                  value: store.setting('adBlock', true) == true,
                  onChanged: (value) {
                    store.setSetting('adBlock', value);
                    browser.updateSettings();
                  },
                ),
              ),
              SettingsRow(
                icon: Icons.smart_display_outlined,
                title: 'Auto-skip YouTube ads',
                subtitle: 'Click Skip when it becomes available',
                trailing: CrockSwitch(
                  semanticLabel: 'Auto-skip YouTube ads',
                  value: browser.youtubeAutoSkipAds,
                  onChanged: (value) {
                    store.setSetting('youtubeAutoSkipAds', value);
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
          Center(
            child: Text(
              'Crock Browser 0.1.2',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Your bookmarks and files stay on your device.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Future<void> _clearWebsiteData(BuildContext context) async {
    final selection = await showCrockDialog<BrowsingDataSelection>(
      context: context,
      builder: (_) => const ClearWebsiteDataDialog(),
    );
    if (selection == null || selection.categories.isEmpty || !context.mounted) {
      return;
    }
    final selected = selection.categories;
    try {
      if (selected.any((option) => option != 'history')) {
        await NativeBridge.instance.call('browser.clearData', {
          'cookies': selected.contains('cookies'),
          'cache': selected.contains('cache'),
          'storage': selected.contains('storage'),
        });
      }
      if (selected.contains('history')) {
        store.setRows('history', []);
        await store.flush();
        if (store.saveError != null) throw StateError(store.saveError!);
      }
      if (context.mounted) {
        crockMessage(context, 'Selected browsing data cleared');
      }
    } catch (error) {
      if (context.mounted) crockMessage(context, error);
    }
  }

  Future<void> _call(BuildContext context, String method) async {
    try {
      await NativeBridge.instance.call(method);
    } catch (error) {
      if (context.mounted) crockMessage(context, error);
    }
  }
}
