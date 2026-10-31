import 'dart:ui';

import 'package:flutter/material.dart';

import 'core/storage/browser_store.dart';
import 'core/theme/crock_theme.dart';
import 'core/theme/app_motion.dart';
import 'features/browser/browser_shell.dart';
import 'shared/widgets/crock_logo.dart';
import 'shared/widgets/selected_builder.dart';
import 'shared/widgets/crock_notification.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final route = PlatformDispatcher.instance.defaultRouteName;
  final store = BrowserStore(route == '/private');
  try {
    await store.load();
    runApp(CrockApp(store: store, downloads: route == '/downloads'));
  } catch (error) {
    runApp(
      MaterialApp(
        theme: CrockTheme.light,
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CrockLogo(size: 72),
                    const SizedBox(height: 24),
                    const Text(
                      'Crock Browser could not open local storage',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      error.toString(),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CrockApp extends StatelessWidget {
  const CrockApp({super.key, required this.store, required this.downloads});
  final BrowserStore store;
  final bool downloads;
  @override
  Widget build(BuildContext context) => SelectedBuilder<String>(
    listenable: store,
    select: () => store.setting(
      'themeMode',
      store.setting('darkTheme', false) == true ? 'dark' : 'system',
    ) as String,
    builder: (context, savedMode) {
      final themeMode = switch (savedMode) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };
      return MaterialApp(
        themeAnimationCurve: AppMotion.curve,
        title: 'Crock Browser',
        debugShowCheckedModeBanner: false,
        builder: (context, child) => TooltipVisibility(
          visible: false,
          child: CrockNotificationHost(child: child!),
        ),
        theme: CrockTheme.light,
        darkTheme: CrockTheme.dark,
        themeMode: themeMode,
        initialRoute: '/',
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (context) =>
              BrowserShell(store: store, openDownloads: downloads),
        ),
      );
    },
  );
}
