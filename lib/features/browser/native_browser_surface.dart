import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../core/models/browser_tab.dart';
import 'browser_controller.dart';
import 'widgets/page_scroll_observer.dart';

class NativeBrowserSurface extends StatelessWidget {
  const NativeBrowserSurface({
    super.key,
    required this.browser,
    required this.tab,
  });
  final BrowserController browser;
  final BrowserTab tab;
  @override
  Widget build(BuildContext context) {
    if (tab.url.isEmpty) return const SizedBox.expand();
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const Center(
        child: Text('Crock Browser uses the Android WebView.'),
      );
    }
    return PageScrollObserver(
      onScroll: (delta) => browser.userScroll(tab, delta),
      child: PlatformViewLink(
        viewType: 'croc/webview',
        surfaceFactory: (context, controller) => AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: const {},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        ),
        onCreatePlatformView: (params) {
          // Compose the WebView directly: texture-backed views can flash while
          // their buffers resize during the address bar animation.
          final controller = PlatformViewsService.initExpensiveAndroidView(
            id: params.id,
            viewType: params.viewType,
            layoutDirection: TextDirection.ltr,
            onFocus: () => params.onFocusChanged(true),
            creationParamsCodec: const StandardMessageCodec(),
            creationParams: {
              'active': browser.isTabActive(tab),
              'url': tab.url.startsWith('http') ? tab.url : '',
              'desktop': tab.desktop,
              'font': browser.store.setting('font', 100),
              'darkTheme': browser.darkTheme,
              'adBlock': browser.store.setting('adBlock', false),
              'youtubeAutoSkipAds': browser.youtubeAutoSkipAds,
              'offerSavePasswords': browser.store.setting(
                'offerSavePasswords',
                true,
              ),
              'passwordPromptBlockedOrigins': browser.store.setting(
                'passwordPromptBlockedOrigins',
                const <String>[],
              ),
            },
          );
          controller.addOnPlatformViewCreatedListener(
            params.onPlatformViewCreated,
          );
          controller.addOnPlatformViewCreatedListener(
            (view) => browser.attach(
              view,
              tab,
              thumbnailBounds: () {
                if (!context.mounted) return null;
                final box = context.findRenderObject();
                if (box is! RenderBox || !box.hasSize) return null;
                final flutterView = View.of(context);
                final scale = flutterView.devicePixelRatio;
                final origin = box.localToGlobal(Offset.zero) * scale;
                return Rect.fromLTWH(
                  origin.dx,
                  origin.dy,
                  box.size.width * scale,
                  box.size.height * scale,
                ).intersect(
                  Rect.fromLTWH(
                    0,
                    0,
                    flutterView.physicalSize.width,
                    flutterView.physicalSize.height -
                        flutterView.viewPadding.bottom,
                  ),
                );
              },
            ),
          );
          controller.create();
          return controller;
        },
      ),
    );
  }
}
