import 'package:flutter/material.dart';

import '../browser/browser_controller.dart';
import 'widgets/browser_tab_card.dart';
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
                  '${widget.browser.tabs.length} open',
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
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 244,
                        ),
                    itemCount: widget.browser.tabs.length,
                    itemBuilder: (context, index) => _card(index),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: widget.browser.tabs.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _card(index),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
  Widget _card(int index) => BrowserTabCard(
    key: ValueKey(widget.browser.tabs[index].id),
    tab: widget.browser.tabs[index],
    selected: index == widget.browser.selected,
    grid: grid,
    onSelect: () {
      widget.browser.select(index);
      Navigator.pop(context);
    },
    onClose: () => widget.browser.close(index),
  );
}
