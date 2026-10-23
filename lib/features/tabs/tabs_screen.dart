import 'package:flutter/material.dart';

import '../browser/browser_controller.dart';
import '../../shared/widgets/crock_logo.dart';
import '../../shared/widgets/feature_scaffold.dart';

class TabsScreen extends StatefulWidget {
  const TabsScreen({super.key, required this.browser});
  final BrowserController browser;
  @override
  State<TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends State<TabsScreen> {
  bool get grid => widget.browser.store.setting('tabGrid', true) == true;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.browser,
    builder: (context, _) => FeatureScaffold(
      title: widget.browser.privateMode ? 'Private tabs' : 'Open tabs',
      actions: [
        IconButton(
          tooltip: 'Change tab view',
          onPressed: () =>
              setState(() => widget.browser.store.setSetting('tabGrid', !grid)),
          icon: Icon(grid ? Icons.view_list_rounded : Icons.grid_view_rounded),
        ),
        PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'reopen') {
              widget.browser.reopenClosed();
            }
            if (value == 'close' &&
                await confirmCrock(
                  context,
                  'Close all tabs?',
                  'Your bookmarks and downloaded files will be kept.',
                )) {
              widget.browser.closeAll();
            }
          },
          itemBuilder: (context) => [
            if (!widget.browser.privateMode)
              const PopupMenuItem(
                value: 'reopen',
                child: Text('Reopen closed tab'),
              ),
            const PopupMenuItem(value: 'close', child: Text('Close all tabs')),
          ],
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Row(
              children: [
                Text(
                  '${widget.browser.tabs.length} tabs',
                  style: const TextStyle(color: Color(0xFF8796A6)),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {
                    widget.browser.newTab();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('New tab'),
                ),
              ],
            ),
          ),
          Expanded(
            child: grid
                ? GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: .9,
                        ),
                    itemCount: widget.browser.tabs.length,
                    itemBuilder: (context, index) => _card(index),
                  )
                : ListView.builder(
                    itemCount: widget.browser.tabs.length,
                    itemBuilder: (context, index) => _card(index),
                  ),
          ),
        ],
      ),
    ),
  );
  Widget _card(int index) {
    final tab = widget.browser.tabs[index];
    final active = index == widget.browser.selected;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: active
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          widget.browser.select(index);
          Navigator.pop(context);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: grid
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const CrockLogo(size: 26),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Close tab',
                          onPressed: () => widget.browser.close(index),
                          icon: const Icon(Icons.close_rounded, size: 19),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      tab.atHome ? 'Home' : tab.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      tab.url.isEmpty
                          ? 'Ready for your next discovery'
                          : Uri.tryParse(tab.url)?.host ?? tab.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8796A6),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                )
              : Row(
                  children: [
                    const CrockLogo(size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(tab.atHome ? 'Home' : tab.title, maxLines: 2),
                    ),
                    IconButton(
                      onPressed: () => widget.browser.close(index),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
