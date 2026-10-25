import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/platform/native_bridge.dart';
import '../../core/storage/browser_store.dart';
import '../../core/theme/crock_theme.dart';
import '../../core/theme/animation_timings.dart';
import '../../shared/widgets/feature_scaffold.dart';
import '../downloads/download_controller.dart';
import '../downloads/download_feedback.dart';
import '../downloads/youtube_quality_menu.dart';
import '../downloads/download_sheet.dart';
import '../downloads/downloads_screen.dart';
import '../files/files_screen.dart';
import '../home/home_screen.dart';
import '../home/shortcuts_screen.dart';
import '../library/library_screen.dart';
import '../privacy/vault_screen.dart';
import '../privacy/login_save_prompt.dart';
import '../reading/reader_screen.dart';
import '../reading/autofill_profile_screen.dart';
import '../reading/clipboard_screen.dart';
import '../settings/settings_screen.dart';
import '../tabs/tabs_screen.dart';
import '../tabs/widgets/tab_window_transition.dart';
import 'browser_controller.dart';
import 'native_browser_surface.dart';
import 'widgets/browser_address_bar.dart';
import 'widgets/tab_toolbar_transition.dart';
import '../../shared/widgets/crock_notification.dart';
import '../../shared/widgets/sliding_address_bar.dart';

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
    with
        WidgetsBindingObserver,
        SingleTickerProviderStateMixin,
        _BrowserActions {
  @override
  late final browser = BrowserController(widget.store);
  @override
  final downloads = DownloadController();
  late final loginPrompts = LoginSavePrompt(store);
  late final StreamSubscription<Map<String, dynamic>> events;
  late final StreamSubscription<Map<String, dynamic>> _completedDownloads;
  final address = TextEditingController(), addressFocus = FocusNode();
  late final AnimationController _addressMotion;
  final _addressContentKey = GlobalKey();
  double _downwardScroll = 0;
  double? _addressScrollThreshold;
  double _upwardScroll = 0;
  bool _addressHideCommitted = false;
  String? _addressTab;
  String? _addressPage;
  bool _openingTabs = false;
  int _featureRouteCount = 0;
  bool _youtubeMenuOpen = false;
  final _tabToolbarMotion = ProxyAnimation(const AlwaysStoppedAnimation(0));
  @override
  BrowserStore get store => widget.store;
  @override
  void initState() {
    super.initState();
    _addressMotion = AnimationController(
      vsync: this,
      value: 1,
      duration: AnimationTimings.addressBarSlideIn,
      reverseDuration: AnimationTimings.addressBarSlideOut,
    );
    addressFocus.addListener(_addressFocused);
    WidgetsBinding.instance.addObserver(this);
    events = browser.events.stream.listen(_event);
    _completedDownloads = downloads.completions.listen((task) {
      if (mounted &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        showDownloadComplete(context, downloads, task);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.openDownloads) _tool('downloads');
      _applyDevice();
    });
  }

  Future<void> _showYouTubeDownload(Map<String, dynamic> event) async {
    if (_youtubeMenuOpen ||
        !mounted ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _youtubeMenuOpen = true;
    try {
      Rect? anchor;
      final bounds = browser.currentViewportBounds;
      final raw = event['anchor'];
      if (bounds != null && raw is Map) {
        final coordinates = [
          'left',
          'top',
          'width',
          'height',
        ].map((key) => raw[key]).toList();
        if (coordinates.every((value) => value is num && value.isFinite)) {
          final values = coordinates
              .map((value) => (value as num).toDouble().clamp(0.0, 1.0))
              .toList();
          final scale = View.of(context).devicePixelRatio;
          anchor = Rect.fromLTWH(
            (bounds.left + values[0] * bounds.width) / scale,
            (bounds.top + values[1] * bounds.height) / scale,
            values[2] * bounds.width / scale,
            values[3] * bounds.height / scale,
          );
        }
      }
      await showYouTubeQualityMenu(
        context,
        url: event['url'] as String,
        downloads: downloads,
        store: store,
        anchor: anchor,
        onView: () => _tool('downloads'),
      );
    } finally {
      _youtubeMenuOpen = false;
    }
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

  @override
  void didChangePlatformBrightness() {
    final themeMode = store.setting(
      'themeMode',
      store.setting('darkTheme', false) == true ? 'dark' : 'system',
    );
    if (themeMode == 'system') {
      browser.updateSettings();
    }
  }

  void _event(Map<String, dynamic> event) {
    if (!mounted) return;
    switch (event['type']) {
      case 'scroll':
        if (store.setting('addressBarMode', 'static') != 'dynamic' ||
            addressFocus.hasFocus ||
            ModalRoute.of(context)?.isCurrent != true) {
          return;
        }
        final delta = (event['deltaY'] as num? ?? 0).toDouble();
        if (!delta.isFinite || delta == 0) return;
        if (delta < 0) {
          // Resizing the viewport can emit reverse inertia without an upward gesture.
          if (event['source'] != 'touch') return;
          // Tiny direction changes during a slow drag should not reopen the bar.
          _upwardScroll -= delta;
          if (_upwardScroll < 4) return;
          _downwardScroll = 0;
          _addressScrollThreshold = null;
          _showAddressBar();
        } else {
          _upwardScroll = 0;
          if (_addressHideCommitted) return;
          final threshold = _addressScrollThreshold ??=
              _visiblePageHeight() * (2 / 3);
          final previous = (_downwardScroll - threshold).clamp(
            0.0,
            double.infinity,
          );
          _downwardScroll += delta;
          final movement =
              (_downwardScroll - threshold).clamp(0.0, double.infinity) -
              previous;
          if (movement > 0) {
            final height =
                _addressContentKey.currentContext?.size?.height ?? 52;
            _addressMotion.stop();
            _addressMotion.value = (_addressMotion.value - movement / height)
                .clamp(0.0, 1.0);
            if (_addressMotion.value <= .8) {
              _addressHideCommitted = true;
              _hideAddressBar();
            }
          }
        }
      case 'loginSuggestion':
        loginPrompts.offer(
          context,
          event,
          isCurrent: () =>
              mounted &&
              WidgetsBinding.instance.lifecycleState ==
                  AppLifecycleState.resumed &&
              !browser.current.atHome &&
              Uri.tryParse(browser.current.url)?.origin == event['origin'] &&
              ModalRoute.of(context)?.isCurrent == true,
          updateSettings: browser.updateSettings,
        );
      case 'download':
        showDownloadSheet(context, downloads, store, event);
      case 'youtubeDownload':
        _showYouTubeDownload(event);
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

  void _addressFocused() {
    if (addressFocus.hasFocus) _showAddressBar();
  }

  double _visiblePageHeight() {
    final bounds = browser.currentViewportBounds;
    if (bounds != null && bounds.height > 0) {
      return bounds.height / View.of(context).devicePixelRatio;
    }
    return (MediaQuery.sizeOf(context).height -
            MediaQuery.paddingOf(context).vertical -
            (_addressContentKey.currentContext?.size?.height ?? 52))
        .clamp(1.0, double.infinity);
  }

  void _showAddressBar() {
    _addressHideCommitted = false;
    if (_addressMotion.value == 1) return;
    if (_addressMotion.isAnimating &&
        _addressMotion.status == AnimationStatus.forward) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _addressMotion.value = 1;
    } else {
      _addressMotion.animateTo(
        1,
        duration: AnimationTimings.addressBarSlideIn,
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _hideAddressBar() async {
    if (_addressMotion.value == 0) return;
    final tabId = browser.current.id;
    try {
      await browser.preservePagePositionDuring(() async {
        if (!mounted || !_addressHideCommitted || browser.current.id != tabId) {
          return;
        }
        if (MediaQuery.disableAnimationsOf(context)) {
          _addressMotion.value = 0;
        } else {
          await _addressMotion
              .animateBack(
                0,
                duration: AnimationTimings.addressBarSlideOut,
                curve: Curves.easeInQuad,
              )
              .orCancel;
        }
        await WidgetsBinding.instance.endOfFrame;
      });
    } on TickerCanceled {
      // An upward gesture or navigation interrupted the automatic slide.
    } on PlatformException {
      // The native page may close while entering or leaving tab overview.
    } on MissingPluginException {
      // Its platform view is no longer attached.
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
  Future<void> _push(Widget screen) async {
    _featureRouteCount++;
    try {
      await browser.setFeatureScreenVisible(true);
      if (!mounted) return;
      final route = MaterialPageRoute<void>(builder: (context) => screen);
      await Navigator.push<void>(context, route);
      await route.completed;
    } finally {
      _featureRouteCount--;
      if (mounted && _featureRouteCount == 0) {
        await browser.setFeatureScreenVisible(false);
      }
    }
  }

  @override
  Future<void> _showTabs() async {
    if (_openingTabs) return;
    _openingTabs = true;
    try {
      // Capture before pausing or covering the WebView with the overview route.
      await browser.captureThumbnails(refresh: true);
      await browser.setTabOverviewVisible(true);
      if (mounted) {
        final route = PageRouteBuilder<void>(
          transitionDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : AnimationTimings.tabOverviewOpen,
          reverseTransitionDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : AnimationTimings.tabOverviewClose,
          pageBuilder: (_, _, _) => TabsScreen(browser: browser),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          ),
        );
        final popped = Navigator.push<void>(context, route);
        _tabToolbarMotion.parent = route.animation;
        await popped;
        await route.completed;
        _tabToolbarMotion.parent = null;
      }
    } finally {
      if (mounted) await browser.setTabOverviewVisible(false);
      _openingTabs = false;
    }
  }

  void _overflowAction(String action) {
    switch (action) {
      case 'back':
        browser.back();
      case 'refresh':
        browser.page('reload');
      case 'find':
        _find();
      case 'newTab':
        browser.newTab();
      case 'newPrivateTab':
        _tool('private');
      case 'downloads':
        _tool('downloads');
      case 'history':
        _tool('history');
      case 'browserMenu':
        _menu();
      case 'settings':
        _tool('settings');
      case 'closeTab':
        browser.close(browser.selected);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([browser, store]),
    builder: (context, _) {
      final tab = browser.current;
      final page = tab.url.split('#').first;
      if (_addressTab != tab.id ||
          tab.atHome ||
          _addressPage != page ||
          store.setting('addressBarMode', 'static') != 'dynamic') {
        _addressTab = tab.id;
        _addressPage = page;
        _addressMotion.stop();
        _addressMotion.value = 1;
        _downwardScroll = 0;
        _addressScrollThreshold = null;
        _upwardScroll = 0;
        _addressHideCommitted = false;
      }
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
            child: LayoutBuilder(
              builder: (context, viewport) => Column(
                children: [
                  if (!tab.atHome)
                    SlidingAddressBar(
                      key: crockAddressBarKey,
                      visibility: _addressMotion,
                      child: BrowserAddressBar(
                        key: _addressContentKey,
                        controller: address,
                        focusNode: addressFocus,
                        url: tab.url,
                        onHome: browser.home,
                        onSubmit: _open,
                        onMenuSelected: _overflowAction,
                        onTabs: _showTabs,
                        tabCount: browser.tabs.length,
                      ),
                    ),
                  if (!tab.atHome && tab.loading)
                    LinearProgressIndicator(value: tab.progress, minHeight: 2),
                  if (!tab.atHome && tab.failed)
                    Container(
                      color: Theme.of(context).colorScheme.errorContainer,
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
                      fit: StackFit.expand,
                      children: [
                        ExcludeSemantics(
                          excluding: tab.atHome || tab.failed,
                          child: IndexedStack(
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
                        ),
                        // Only this transparent anchor participates in the Hero.
                        // The native WebViews remain mounted throughout the flight.
                        if (!tab.atHome)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: HeroMode(
                                enabled: !MediaQuery.disableAnimationsOf(
                                  context,
                                ),
                                child: Hero(
                                  tag: tabWindowHero(tab.id),
                                  createRectTween: tabWindowRectTween,
                                  flightShuttleBuilder:
                                      (
                                        context,
                                        animation,
                                        direction,
                                        from,
                                        to,
                                      ) => tabPreviewFlight(
                                        context,
                                        animation,
                                        direction,
                                        from,
                                        to,
                                        preview: tab.thumbnail == null
                                            ? null
                                            : MemoryImage(tab.thumbnail!),
                                      ),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),
                        if (tab.failed && !tab.atHome)
                          ColoredBox(
                            color: Theme.of(context).colorScheme.surface,
                            child: SizedBox.expand(
                              child: CrockEmpty(
                                title: 'This page could not be reached',
                                detail: 'Check the address and your connection, then tap Retry above.',
                              ),
                            ),
                          ),
                        if (tab.atHome)
                          Hero(
                            tag: tabWindowHero(tab.id),
                            createRectTween: tabWindowRectTween,
                            flightShuttleBuilder: homeTabWindowFlight,
                            child: Material(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  HomeScreen(
                                    store: store,
                                    privateMode: browser.privateMode,
                                    onSearch: _open,
                                    onTool: _tool,
                                    onShortcut: (site) =>
                                        _open(site['url'] as String),
                                    onEditShortcut: (site) => editShortcut(
                                      context,
                                      store,
                                      site.isEmpty ? null : site,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (tab.atHome &&
                            MediaQuery.viewInsetsOf(context).bottom == 0)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: _navigation(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  Widget _navigation() => TabToolbarTransition(
    animation: _tabToolbarMotion,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: .14),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: CrockTheme.blue.withValues(alpha: .06),
              blurRadius: 18,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface
                    .withValues(alpha: .9),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant
                      .withValues(alpha: .65),
                  width: 1,
                ),
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
                            (browser.current.atHome &&
                                browser.current.url.isNotEmpty)
                        ? browser.forward
                        : null,
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                  IconButton(
                    tooltip: 'Menu',
                    onPressed: _menu,
                    icon: const Icon(Icons.menu_rounded, size: 28),
                  ),
                  IconButton(
                    tooltip: '${browser.tabs.length} open tabs',
                    onPressed: _showTabs,
                    icon: Container(
                      width: 24,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(
                          width: 1.8,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${browser.tabs.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Home',
                    onPressed: browser.home,
                    icon: const Icon(Icons.home_outlined, size: 27),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    events.cancel();
    _completedDownloads.cancel();
    browser.persist();
    browser.dispose();
    downloads.dispose();
    address.dispose();
    addressFocus.dispose();
    _addressMotion.dispose();
    super.dispose();
  }
}
