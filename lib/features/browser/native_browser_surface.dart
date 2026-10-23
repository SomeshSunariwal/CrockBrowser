import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/browser_tab.dart';
import 'browser_controller.dart';

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
    return AndroidView(
      viewType: 'croc/webview',
      layoutDirection: TextDirection.ltr,
      creationParamsCodec: const StandardMessageCodec(),
      creationParams: {
        'url': tab.url.startsWith('http') ? tab.url : '',
        'desktop': tab.desktop,
        'font': browser.store.setting('font', 100),
        'adBlock': browser.store.setting('adBlock', false),
        'offerSavePasswords': browser.store.setting('offerSavePasswords', true),
        'passwordPromptBlockedOrigins': browser.store.setting(
          'passwordPromptBlockedOrigins',
          const <String>[],
        ),
      },
      onPlatformViewCreated: (view) => browser.attach(view, tab),
    );
  }
}
