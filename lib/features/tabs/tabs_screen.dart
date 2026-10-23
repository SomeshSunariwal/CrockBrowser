import 'package:flutter/material.dart';

import '../../core/models/browser_tab.dart';
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

  Widget _card(int index) {
    final tab = widget.browser.tabs[index];
    return _TabSwipeDismissible(
      key: ValueKey('dismiss-${tab.id}'),
      tab: tab,
      selected: index == widget.browser.selected,
      grid: grid,
      onSelect: () {
        widget.browser.select(index);
        Navigator.pop(context);
      },
      onClose: () => widget.browser.close(index),
      onDismissed: () => widget.browser.close(index),
    );
  }
}

class _TabSwipeDismissible extends StatefulWidget {
  const _TabSwipeDismissible({
    super.key,
    required this.tab,
    required this.selected,
    required this.grid,
    required this.onSelect,
    required this.onClose,
    required this.onDismissed,
  });

  final BrowserTab tab;
  final bool selected, grid;
  final VoidCallback onSelect, onClose, onDismissed;

  @override
  State<_TabSwipeDismissible> createState() => _TabSwipeDismissibleState();
}

class _TabSwipeDismissibleState extends State<_TabSwipeDismissible> {
  double _opacity = 1;

  @override
  Widget build(BuildContext context) => Dismissible(
    key: ValueKey(widget.tab.id),
    direction: DismissDirection.up,
    movementDuration: const Duration(milliseconds: 220),
    resizeDuration: const Duration(milliseconds: 220),
    dismissThresholds: const {DismissDirection.up: .22},
    onUpdate: (details) {
      final next = (1 - details.progress).clamp(0.0, 1.0).toDouble();
      if ((next - _opacity).abs() > .01) setState(() => _opacity = next);
    },
    onDismissed: (_) => widget.onDismissed(),
    child: Opacity(
      opacity: _opacity,
      child: BrowserTabCard(
        tab: widget.tab,
        selected: widget.selected,
        grid: widget.grid,
        onSelect: widget.onSelect,
        onClose: widget.onClose,
      ),
    ),
  );
}
