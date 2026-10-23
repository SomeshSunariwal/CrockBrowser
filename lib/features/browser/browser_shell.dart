import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/platform/native_bridge.dart';
import '../../core/storage/browser_store.dart';
import '../../core/theme/crock_theme.dart';
import '../../shared/widgets/crock_logo.dart';
import '../../shared/widgets/feature_scaffold.dart';
import '../downloads/download_controller.dart';
import '../downloads/download_sheet.dart';
import '../downloads/downloads_screen.dart';
import '../files/files_screen.dart';
import '../home/home_screen.dart';
import '../home/shortcuts_screen.dart';
import '../library/library_screen.dart';
import '../privacy/vault_screen.dart';
import '../reading/reader_screen.dart';
import '../reading/autofill_profile_screen.dart';
import '../reading/clipboard_screen.dart';
import '../settings/settings_screen.dart';
import '../tabs/tabs_screen.dart';
import 'browser_controller.dart';
import 'native_browser_surface.dart';

part 'browser_actions.dart';

class BrowserShell extends StatefulWidget {
  const BrowserShell({
    super.key,
    required this.store,
    this.openDownloads = false,
  });
  final BrowserStore store;
  final bool openDownloads;
  @override
  State<BrowserShell> createState() => _BrowserShellState();
}

class _BrowserShellState extends State<BrowserShell>
    with WidgetsBindingObserver, _BrowserActions {
  @override
  late final browser = BrowserController(widget.store);
  @override
  late final downloads = DownloadController();
  late final StreamSubscription<Map<String, dynamic>> events;
  final address = TextEditingController(), addressFocus = FocusNode();
  @override
  BrowserStore get store => widget.store;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    events = browser.events.stream.listen(_event);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.openDownloads) _tool('downloads');
      _applyDevice();
    });
  }

  Future<void> _applyDevice() async {
    try {
      await NativeBridge.instance.call('device.brightness', {
        'value': store.setting('brightness', -1),
      });
      await NativeBridge.instance.call('device.rotation', {
        'value': store.setting('rotation', 'auto'),
      });
    } catch (error) {
      if (mounted) crockMessage(context, error);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      store.reloadShared();
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      store.flush();
    }
  }

  void _event(Map<String, dynamic> event) {
    if (!mounted) return;
    switch (event['type']) {
      case 'download':
        showDownloadSheet(context, downloads, store, event);
      case 'navigate':
        if (event['screen'] == 'downloads') _tool('downloads');
      case 'message':
        crockMessage(context, event['text'] ?? '');
      case 'context':
        _contextLink(event);
      case 'externalLink':
        if (event['url'].toString().startsWith('magnet:')) {
          showDownloadSheet(context, downloads, store, {'url': event['url']});
          return;
        }
        crockMessage(
          context,
          'This link uses an external application scheme. Long-press a normal web link to copy or share it.',
        );
    }
  }

  @override
  Future<void> _open(String value) async {
    FocusScope.of(context).unfocus();
    try {
      await browser.open(value);
    } catch (error) {
      if (mounted) crockMessage(context, error);
    }
  }

  @override
  void _push(Widget screen) => Navigator.push(
    context,
    MaterialPageRoute<void>(builder: (context) => screen),
  );
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([browser, store]),
    builder: (context, _) {
      final tab = browser.current;
      if (!addressFocus.hasFocus && address.text != tab.url) {
        address.text = tab.url;
      }
      return PopScope(
        canPop: tab.atHome && !browser.privateMode,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            if (tab.atHome && browser.privateMode) {
              NativeBridge.instance.call('private.close');
            } else {
              browser.back();
            }
          }
        },
        child: Scaffold(
          body: SafeArea(
            child: Column(
              children: [
                if (!tab.atHome)
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(6, 2, 6, 5),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Home',
                          onPressed: browser.home,
                          icon: const Icon(Icons.home_outlined),
                        ),
                        Expanded(
                          child: TextField(
                            controller: address,
                            focusNode: addressFocus,
                            textInputAction: TextInputAction.go,
                            keyboardType: TextInputType.url,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              hintText: 'Search or enter URL',
                              prefixIcon: Icon(
                                tab.url.startsWith('https://')
                                    ? Icons.lock_outline
                                    : Icons.public_rounded,
                                size: 16,
                              ),
                            ),
                            onTap: () => address.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: address.text.length,
                            ),
                            onSubmitted: _open,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: () => browser.page('reload'),
                          icon: const Icon(Icons.refresh_rounded, size: 22),
                        ),
                      ],
                    ),
                  ),
                if (!tab.atHome && tab.loading)
                  LinearProgressIndicator(value: tab.progress, minHeight: 2),
                if (!tab.atHome && tab.failed)
                  Container(
                    color: const Color(0xFFFFF0E8),
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off_rounded, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Could not load this page. Check your connection and try again.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        TextButton(
                          onPressed: () => browser.page('reload'),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      IndexedStack(
                        index: browser.selected,
                        children: browser.tabs
                            .map(
                              (item) => NativeBrowserSurface(
                                key: ValueKey(item.id),
                                browser: browser,
                                tab: item,
                              ),
                            )
                            .toList(),
                      ),
                      if (tab.failed && !tab.atHome)
                        ColoredBox(
                          color: Colors.white,
                          child: SizedBox.expand(
                            child: CrockEmpty(
                              title: 'This page could not be reached',
                              detail: 'Check the address and your connection, then tap Retry above.',
                            ),
                          ),
                        ),
                      if (tab.atHome)
                        HomeScreen(
                          store: store,
                          privateMode: browser.privateMode,
                          onSearch: _open,
                          onTool: _tool,
                          onShortcut: (site) => _open(site['url'] as String),
                          onEditShortcut: (site) => editShortcut(
                            context,
                            store,
                            site.isEmpty ? null : site,
                          ),
                        ),
                    ],
                  ),
                ),
                if (MediaQuery.viewInsetsOf(context).bottom == 0) _navigation(),
              ],
            ),
          ),
        ),
      );
    },
  );
  Widget _navigation() => Container(
    height: 58,
    decoration: const BoxDecoration(
      color: CrockTheme.background,
      border: Border(top: BorderSide(color: Color(0xFFE9EEF5), width: .5)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        IconButton(
          tooltip: 'Back',
          onPressed: browser.current.atHome ? null : browser.back,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        IconButton(
          tooltip: 'Forward',
          onPressed:
              browser.current.canForward ||
                  (browser.current.atHome && browser.current.url.isNotEmpty)
              ? browser.forward
              : null,
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
        IconButton(
          tooltip: 'Menu',
          onPressed: _menu,
          icon: const Icon(Icons.menu_rounded, size: 29),
        ),
        IconButton(
          tooltip: '${browser.tabs.length} open tabs',
          onPressed: () => _push(TabsScreen(browser: browser)),
          icon: Container(
            width: 24,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(width: 1.8, color: const Color(0xFF283641)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${browser.tabs.length}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Home',
          onPressed: browser.home,
          icon: const Icon(Icons.home_outlined, size: 28),
        ),
      ],
    ),
  );
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    events.cancel();
    browser.persist();
    browser.dispose();
    downloads.dispose();
    address.dispose();
    addressFocus.dispose();
    super.dispose();
  }
}
