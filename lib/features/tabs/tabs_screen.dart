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
                Expanded(
                  child: Text(
                    '${widget.browser.tabs.length} open',
                    style: const TextStyle(color: Color(0xFF8796A6)),
                  ),
                ),
                const SizedBox(width: 12),
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

class _TabSwipeDismissibleState extends State<_TabSwipeDismissible>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  Offset _offset = Offset.zero, _begin = Offset.zero, _target = Offset.zero;
  Axis _axis = Axis.horizontal;
  bool _closing = false;

  double _extent = 1;
  double get _progress =>
      (_axis == Axis.horizontal ? _offset.dx : -_offset.dy) / _extent;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this)
      ..addListener(() {
        setState(
          () => _offset = Offset.lerp(
            _begin,
            _target,
            Curves.easeOutCubic.transform(_motion.value),
          )!,
        );
      });
  }

  void _drag(DragUpdateDetails details, Axis axis) {
    if (_closing) return;
    _motion.stop();
    _axis = axis;
    _extent = axis == Axis.horizontal
        ? (context.size?.width ?? 1)
        : (context.size?.height ?? 1);
    setState(() {
      _offset = axis == Axis.horizontal
          ? Offset(
              (_offset.dx + details.delta.dx).clamp(0.0, double.infinity),
              0,
            )
          : Offset(
              0,
              (_offset.dy + details.delta.dy).clamp(
                double.negativeInfinity,
                0.0,
              ),
            );
    });
  }

  Future<void> _settle(double velocity) async {
    if (_closing) return;
    final dismiss =
        _progress >= .22 ||
        (_axis == Axis.horizontal ? velocity > 700 : velocity < -700);
    _closing = dismiss;
    _begin = _offset;
    _target = dismiss
        ? (_axis == Axis.horizontal ? Offset(_extent, 0) : Offset(0, -_extent))
        : Offset.zero;
    _motion.duration = Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220,
    );
    try {
      await _motion.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (mounted && dismiss) widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onHorizontalDragUpdate: (details) => _drag(details, Axis.horizontal),
    onVerticalDragUpdate: (details) => _drag(details, Axis.vertical),
    onHorizontalDragEnd: (details) => _settle(details.primaryVelocity ?? 0),
    onVerticalDragEnd: (details) => _settle(details.primaryVelocity ?? 0),
    onHorizontalDragCancel: () => _settle(0),
    onVerticalDragCancel: () => _settle(0),
    child: Transform.translate(
      offset: _offset,
      child: Opacity(
        opacity: _offset == Offset.zero ? 1 : (1 - _progress).clamp(0.0, 1.0),
        child: BrowserTabCard(
          tab: widget.tab,
          selected: widget.selected,
          grid: widget.grid,
          onSelect: widget.onSelect,
          onClose: widget.onClose,
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }
}
