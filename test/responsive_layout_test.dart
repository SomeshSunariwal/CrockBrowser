import 'dart:io';
import 'dart:ui' as ui;

import 'package:crockbrowser/core/storage/browser_store.dart';
import 'package:crockbrowser/core/theme/crock_theme.dart';
import 'package:crockbrowser/features/browser/browser_controller.dart';
import 'package:crockbrowser/features/downloads/download_controller.dart';
import 'package:crockbrowser/features/downloads/downloads_screen.dart';
import 'package:crockbrowser/features/files/files_screen.dart';
import 'package:crockbrowser/features/home/home_screen.dart';
import 'package:crockbrowser/features/home/shortcuts_screen.dart';
import 'package:crockbrowser/features/library/library_screen.dart';
import 'package:crockbrowser/features/privacy/vault_screen.dart';
import 'package:crockbrowser/features/reading/autofill_profile_screen.dart';
import 'package:crockbrowser/features/reading/clipboard_screen.dart';
import 'package:crockbrowser/features/reading/reader_screen.dart';
import 'package:crockbrowser/features/settings/search_engines_screen.dart';
import 'package:crockbrowser/features/settings/settings_screen.dart';
import 'package:crockbrowser/features/tabs/tabs_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!const bool.fromEnvironment('UX_SCREENSHOTS')) return;
    final fonts = 'tools/vendor/flutter/bin/cache/artifacts/material_fonts';
    final text = FontLoader('Roboto');
    for (final weight in ['regular', 'medium', 'bold', 'light']) {
      text.addFont(
        File('$fonts/roboto-$weight.ttf')
            .readAsBytes()
            .then(ByteData.sublistView),
      );
    }
    await text.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        File('$fonts/materialicons-regular.otf')
            .readAsBytes()
            .then(ByteData.sublistView),
      );
    await icons.load();
  });
  const scenarios = [
    (Size(320, 568), 1.0),
    (Size(390, 844), 1.0),
    (Size(320, 568), 1.4),
    (Size(640, 360), 1.0),
  ];
  for (final scenario in scenarios) {
    final theme = const bool.fromEnvironment('UX_DARK')
        ? CrockTheme.dark
        : CrockTheme.light;
    testWidgets(
      'screen alignment and overflow at ${scenario.$1}, text ${scenario.$2}',
      (tester) async {
        tester.view.physicalSize = scenario.$1;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(
          const MethodChannel('croc/events'),
          (_) async => null,
        );
        messenger.setMockMethodCallHandler(const MethodChannel('croc/native'), (
          call,
        ) async {
          if (call.method.endsWith('.list')) return <Object>[];
          return null;
        });
        final store = BrowserStore(true);
        store.data['settings'] = <String, dynamic>{};
        final browser = BrowserController(store);
        final downloads = DownloadController();
        await tester.pump();
        downloads.tasks = [
          {
            'id': 'layout-download',
            'name': 'A long example filename for alignment.bin',
            'url': 'https://example.test/file',
            'state': 'paused',
            'bytes': 1024,
            'total': 8192,
            'speed': 0,
          },
        ];
        final screens = <String, Widget>{
          'Normal Home': Scaffold(
            body: HomeScreen(
              store: store,
              privateMode: false,
              onSearch: (_) {},
              onTool: (_) {},
              onShortcut: (_) {},
              onEditShortcut: (_) {},
            ),
          ),
          'Home': Scaffold(
            body: HomeScreen(
              store: store,
              privateMode: true,
              onSearch: (_) {},
              onTool: (_) {},
              onShortcut: (_) {},
              onEditShortcut: (_) {},
            ),
          ),
          'Downloads': DownloadsScreen(downloads: downloads, store: store),
          'Settings': SettingsScreen(browser: browser),
          'Tabs': TabsScreen(browser: browser),
          'Files': const FilesScreen(),
          'Media': const FilesScreen(media: true),
          'Bookmarks': LibraryScreen(
            store: store,
            mode: 'bookmarks',
            onOpen: (_) {},
            onOffline: (_) {},
          ),
          'History': LibraryScreen(
            store: store,
            mode: 'history',
            onOpen: (_) {},
            onOffline: (_) {},
          ),
          'Offline': LibraryScreen(
            store: store,
            mode: 'offline',
            onOpen: (_) {},
            onOffline: (_) {},
          ),
          'Private Space': const VaultScreen(),
          'Passwords': const VaultScreen(passwords: true),
          'Autofill': const AutofillProfileScreen(),
          'Clipboard': ClipboardScreen(store: store, onOpen: (_) {}),
          'Reader': ReaderScreen(
            store: store,
            article: const {
              'title': 'Example article',
              'text': 'Example article body.',
              'url': 'https://example.test',
            },
          ),
          'Search engines': SearchEnginesScreen(store: store),
          'Shortcuts': ShortcutsScreen(store: store),
        };
        final failures = <String>[];
        final errorHandler = FlutterError.onError;
        FlutterError.onError = (details) {
          debugPrint(details.toString());
          errorHandler?.call(details);
        };
        for (final screen in screens.entries) {
          final captureKey = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              theme: const bool.fromEnvironment('UX_SCREENSHOTS')
                  ? theme.copyWith(
                      textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
                      primaryTextTheme: theme.primaryTextTheme.apply(
                        fontFamily: 'Roboto',
                      ),
                    )
                  : theme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scenario.$2)),
                child: child!,
              ),
              home: RepaintBoundary(key: captureKey, child: screen.value),
            ),
          );
          await tester.pumpAndSettle();
          if (const bool.fromEnvironment('UX_SCREENSHOTS') &&
              scenario.$1.width == 390) {
            final boundary =
                captureKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 2);
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '.tmp/ux-${screen.key.toLowerCase().replaceAll(' ', '-')}.png',
              ).writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }
          Object? error;
          while ((error = tester.takeException()) != null) {
            failures.add('${screen.key}: $error');
          }
          final vertical = find.byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
          );
          for (
            var scroll = 0;
            scroll < 8 && vertical.evaluate().isNotEmpty;
            scroll++
          ) {
            final position = tester
                .state<ScrollableState>(vertical.first)
                .position;
            if (position.pixels >= position.maxScrollExtent) break;
            await tester.drag(vertical.first, const Offset(0, -500));
            await tester.pumpAndSettle();
            while ((error = tester.takeException()) != null) {
              failures.add('${screen.key} after scrolling: $error');
            }
          }
          await tester.pumpWidget(const SizedBox());
        }
        FlutterError.onError = errorHandler;
        downloads.dispose();
        browser.dispose();
        store.dispose();
        expect(failures, isEmpty, reason: failures.join('\n'));
      },
    );
  }
}
