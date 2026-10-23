part of 'browser_shell.dart';

/// Feature navigation and page actions, separate from browser chrome and lifecycle.
mixin _BrowserActions on State<BrowserShell> {
  BrowserController get browser;
  DownloadController get downloads;
  BrowserStore get store;
  Future<void> _open(String value);
  void _push(Widget screen);

  void _tool(String name) {
    switch (name) {
      case 'downloads':
        _push(DownloadsScreen(downloads: downloads, store: store));
      case 'bookmarks':
        _library('bookmarks');
      case 'history':
        _library('history');
      case 'offline':
        _library('offline');
      case 'files':
        _push(const FilesScreen());
      case 'media':
        _push(const FilesScreen(media: true));
      case 'menu':
        _menu();
      case 'settings':
        _push(SettingsScreen(browser: browser));
      case 'tabs':
        _push(TabsScreen(browser: browser));
      case 'qr':
        _scan();
      case 'closePrivate':
        NativeBridge.instance.call('private.close');
      case 'private':
        NativeBridge.instance.call('private.open');
      case 'vault':
        _push(const VaultScreen());
      case 'passwords':
        _push(const VaultScreen(passwords: true));
      case 'clipboard':
        _push(ClipboardScreen(store: store, onOpen: _open));
      case 'reader':
        _reader();
      case 'saveOffline':
        _saveOffline();
      case 'pageMedia':
        _pageMedia();
      case 'find':
        _find();
      case 'meta':
        _metaSearch();
      case 'saveLogin':
        _saveLogin();
      case 'fillLogin':
        _fillLogin();
      case 'profile':
        _push(const AutofillProfileScreen());
      case 'fillProfile':
        _fillProfile();
      case 'hideAd':
        _hideElement();
      case 'shortcuts':
        _push(ShortcutsScreen(store: store));
    }
  }

  void _library(String mode) => _push(
    LibraryScreen(
      store: store,
      mode: mode,
      onOpen: _open,
      onOffline: (item) => browser.openOffline(item),
    ),
  );
  void _menu() {
    final items = [
      ('Bookmarks', Icons.bookmark_outline, 'bookmarks'),
      ('History', Icons.history_rounded, 'history'),
      ('Downloads', Icons.download_rounded, 'downloads'),
      ('Files', Icons.folder_outlined, 'files'),
      ('Settings', Icons.tune_rounded, 'settings'),
      ('Add bookmark', Icons.bookmark_add_outlined, 'addBookmark'),
      ('Private tabs', Icons.visibility_off_outlined, 'private'),
      ('New tab', Icons.add_rounded, 'newTab'),
      ('Share page', Icons.ios_share_rounded, 'share'),
      ('Page tools', Icons.widgets_outlined, 'tools'),
    ];
    showCrockSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5, bottom: 14),
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4DDE8),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            GridView.count(
              crossAxisCount: 5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: .8,
              children: items
                  .map(
                    (item) => InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.pop(context);
                        switch (item.$3) {
                          case 'addBookmark':
                            _bookmark();
                          case 'newTab':
                            browser.newTab();
                          case 'share':
                            _share();
                          case 'tools':
                            _tools();
                          default:
                            _tool(item.$3);
                        }
                      },
                      child: Column(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFFEAF3FF),
                            child: Icon(item.$2, color: CrockTheme.blue),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            item.$1,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _tools() {
    final tools = [
      ('Reader & translation', Icons.chrome_reader_mode_outlined, 'reader'),
      ('Save page offline', Icons.offline_pin_outlined, 'saveOffline'),
      ('Saved offline pages', Icons.download_done_rounded, 'offline'),
      ('Find in page', Icons.search_rounded, 'find'),
      ('Meta search', Icons.travel_explore_rounded, 'meta'),
      ('Page media / downloader', Icons.video_collection_outlined, 'pageMedia'),
      ('Save login', Icons.password_rounded, 'saveLogin'),
      ('Autofill saved login', Icons.key_rounded, 'fillLogin'),
      ('Saved passwords', Icons.lock_outline, 'passwords'),
      ('Autofill contact profile', Icons.person_outline, 'profile'),
      ('Fill contact details', Icons.contact_page_outlined, 'fillProfile'),
      ('Private Space', Icons.shield_outlined, 'vault'),
      ('Clipboard manager', Icons.content_paste_rounded, 'clipboard'),
      ('QR / barcode scanner', Icons.qr_code_scanner, 'qr'),
      ('Manage shortcuts', Icons.grid_view_rounded, 'shortcuts'),
      ('Hide an ad / element', Icons.block_rounded, 'hideAd'),
    ];
    showCrockSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .72,
        minChildSize: .4,
        maxChildSize: .95,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            const Text(
              'Browser tools',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Desktop site'),
              value: browser.current.desktop,
              onChanged: browser.current.atHome
                  ? null
                  : (value) {
                      Navigator.pop(context);
                      browser.toggleDesktop();
                    },
            ),
            ...tools.map(
              (item) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(item.$2, color: CrockTheme.blue),
                title: Text(item.$1),
                onTap: () {
                  Navigator.pop(context);
                  _tool(item.$3);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _needPage() {
    if (browser.current.atHome) {
      crockMessage(context, 'Open a webpage first');
      return false;
    }
    return true;
  }

  void _bookmark() {
    if (!_needPage()) return;
    store.add('bookmarks', {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'title': browser.current.title,
      'url': browser.current.url,
      'folder': '',
    });
    crockMessage(context, 'Bookmark saved. Edit or move it from Bookmarks.');
  }

  Future<void> _share() async {
    if (!_needPage()) return;
    try {
      await NativeBridge.instance.call('device.share', {
        'text': browser.current.url,
      });
    } catch (e) {
      if (mounted) crockMessage(context, e);
    }
  }

  Future<void> _reader() async {
    if (!_needPage()) return;
    try {
      final article = await browser.page('reader');
      if (article is Map && mounted) {
        _push(
          ReaderScreen(
            article: Map<String, dynamic>.from(article),
            store: store,
          ),
        );
      }
    } catch (e) {
      if (mounted) crockMessage(context, e);
    }
  }

  Future<void> _saveOffline() async {
    if (!_needPage()) return;
    try {
      await browser.page('offline');
      if (mounted) crockMessage(context, 'Page saved for offline browsing');
    } catch (e) {
      if (mounted) crockMessage(context, e);
    }
  }

  Future<void> _scan() async {
    try {
      final value = await NativeBridge.instance.call<String>('qr.scan');
      if (value != null && mounted) {
        final open = await confirmCrock(context, 'Scanned content', value);
        if (open) _open(value);
      }
    } catch (e) {
      if (mounted) crockMessage(context, e);
    }
  }

  Future<void> _find() async {
    if (!_needPage()) return;
    final input = TextEditingController();
    await showCrockSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: input,
                autofocus: true,
                decoration: const InputDecoration(hintText: 'Find in page'),
                onChanged: (value) => browser.page('find', {'text': value}),
              ),
            ),
            IconButton(
              tooltip: 'Previous match',
              onPressed: () => browser.page('findNext', {'forward': false}),
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            IconButton(
              tooltip: 'Next match',
              onPressed: () => browser.page('findNext', {'forward': true}),
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
          ],
        ),
      ),
    );
    input.dispose();
    await browser.page('find', {'text': ''});
  }

  Future<void> _metaSearch() async {
    final input = TextEditingController();
    final selected = <String>{store.setting('engine', 'google') as String};
    await showCrockDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Meta search'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: input,
                  decoration: const InputDecoration(labelText: 'Search query'),
                ),
                const SizedBox(height: 10),
                ...store
                    .rows('engines')
                    .map(
                      (engine) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(engine['name'] as String),
                        value: selected.contains(engine['id']),
                        onChanged: (checked) => setLocal(() {
                          if (checked == true) {
                            selected.add(engine['id'] as String);
                          } else {
                            selected.remove(engine['id']);
                          }
                        }),
                      ),
                    ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (input.text.trim().isEmpty || selected.isEmpty) return;
                for (final engine in selected) {
                  browser.newTab(
                    browser.resolve(input.text.trim(), engine: engine),
                  );
                }
                Navigator.pop(context);
              },
              child: const Text('Search in tabs'),
            ),
          ],
        ),
      ),
    );
    input.dispose();
  }

  Future<void> _contextLink(Map<String, dynamic> event) async {
    final url = event['url'] as String? ?? '';
    await showCrockSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(url, maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Open in new tab'),
              onTap: () {
                Navigator.pop(context);
                browser.newTab(url);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy link'),
              onTap: () {
                Navigator.pop(context);
                NativeBridge.instance.call('clipboard.write', {'text': url});
              },
            ),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Download link'),
              onTap: () {
                Navigator.pop(context);
                _downloadMedia({'url': url});
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadMedia(Map<String, dynamic> media) async {
    try {
      final contextData = await browser.page('requestContext', {
        'url': media['url'],
      });
      if (mounted) {
        await showDownloadSheet(context, downloads, store, {
          ...media,
          'headers': contextData ?? {},
        });
      }
    } catch (e) {
      if (mounted) crockMessage(context, e);
    }
  }

  Future<void> _playMedia(Map<String, dynamic> item) async {
    try {
      final headers = await browser.page('requestContext', {
        'url': item['url'],
      });
      await NativeBridge.instance.call('media.play', {
        'uri': item['url'],
        'headers': headers ?? {},
      });
    } catch (error) {
      if (mounted) crockMessage(context, error);
    }
  }

  Future<void> _pageMedia() async {
    if (!_needPage()) return;
    try {
      final dom = await browser.page('media');
      final media = <Map<String, dynamic>>[
        ...browser.foundMedia[browser.current.id] ?? [],
      ];
      if (dom is List) {
        for (final row in dom) {
          final entry = Map<String, dynamic>.from(row as Map);
          if (!media.any((item) => item['url'] == entry['url'])) {
            media.add(entry);
          }
        }
      }
      if (!mounted) return;
      await showCrockSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: media.isEmpty
              ? const CrockEmpty(
                  title: 'No direct media found yet',
                  detail: 'Start playing media on the page, then open this panel again. Blob and protected streams cannot be downloaded as direct files.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    const Text(
                      'Page media',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...media.map(
                      (item) => Card(
                        child: ListTile(
                          title: Text(
                            item['title'] as String? ?? 'Media file',
                            maxLines: 2,
                          ),
                          subtitle: Text(
                            item['url'] as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Play',
                                onPressed: () => _playMedia(item),
                                icon: const Icon(Icons.play_circle_outline),
                              ),
                              IconButton(
                                tooltip: 'Download',
                                onPressed: () {
                                  Navigator.pop(context);
                                  _downloadMedia(item);
                                },
                                icon: const Icon(Icons.download_outlined),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      );
    } catch (e) {
      if (mounted) crockMessage(context, e);
    }
  }

  Future<void> _saveLogin() async {
    if (!_needPage()) return;
    try {
      final form = await browser.page('form');
      if (form is! Map ||
          form['password'] == null ||
          (form['password'] as String).isEmpty) {
        if (mounted) {
          crockMessage(
            context,
            'Fill a login form before saving its credentials',
          );
        }
        return;
      }
      if (!mounted ||
          !await confirmCrock(
            context,
            'Save this login?',
            'Store ${form['username']} for ${form['origin']} in encrypted local storage?',
          )) {
        return;
      }
      if (await NativeBridge.instance.call<bool>('vault.unlock') != true) {
        return;
      }
      await NativeBridge.instance.call('passwords.save', {
        'id': DateTime.now().microsecondsSinceEpoch.toString(),
        ...Map<String, dynamic>.from(form),
      });
      await NativeBridge.instance.call('vault.lock');
      if (mounted) crockMessage(context, 'Login saved locally');
    } catch (e) {
      if (mounted) crockMessage(context, e);
    }
  }

  Future<void> _fillLogin() async {
    if (!_needPage()) return;
    try {
      if (await NativeBridge.instance.call<bool>('vault.unlock') != true) {
        return;
      }
      final origin = Uri.parse(browser.current.url).origin;
      final rows = (await NativeBridge.instance.list('passwords.list'))
          .where((row) => row['origin'] == origin)
          .toList();
      if (!mounted) return;
      if (rows.isEmpty) {
        crockMessage(context, 'No saved login matches this website');
        await NativeBridge.instance.call('vault.lock');
        return;
      }
      await showCrockSheet<void>(
        context: context,
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: rows
              .map(
                (row) => ListTile(
                  leading: const Icon(Icons.key_rounded),
                  title: Text(row['username'] as String? ?? 'Saved login'),
                  subtitle: Text(origin),
                  onTap: () {
                    Navigator.pop(context);
                    browser.page('fill', row);
                  },
                ),
              )
              .toList(),
        ),
      );
      await NativeBridge.instance.call('vault.lock');
    } catch (e) {
      if (mounted) crockMessage(context, e);
    }
  }

  Future<void> _fillProfile() async {
    if (!_needPage()) return;
    try {
      if (await NativeBridge.instance.call<bool>('vault.unlock') != true) {
        return;
      }
      final profiles = await NativeBridge.instance.list('profiles.list');
      if (profiles.isEmpty) {
        if (mounted) _push(const AutofillProfileScreen());
        return;
      }
      final result = await browser.page('fillProfile', {
        ...profiles.first,
        'origin': Uri.parse(browser.current.url).origin,
      });
      if (mounted) {
        crockMessage(
          context,
          'Filled $result contact fields. Review before submitting.',
        );
      }
    } catch (error) {
      if (mounted) crockMessage(context, error);
    } finally {
      await NativeBridge.instance.call('vault.lock');
    }
  }

  Future<void> _hideElement() async {
    if (!_needPage()) return;
    try {
      await browser.page('pickElement');
      if (mounted) {
        crockMessage(
          context,
          'Tap the ad or element you want to hide on this site',
        );
      }
    } catch (e) {
      if (mounted) crockMessage(context, e);
    }
  }
}
