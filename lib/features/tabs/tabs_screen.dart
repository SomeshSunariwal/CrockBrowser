import '../../shared/widgets/crock_dropdown.dart';

import 'package:flutter/material.dart';

import '../../core/models/browser_tab.dart';
import '../../core/theme/animation_timings.dart';
import '../../core/theme/app_motion.dart';
import '../browser/browser_controller.dart';
import 'widgets/browser_tab_card.dart';
import 'widgets/tab_window_transition.dart';
import '../../shared/widgets/feature_scaffold.dart';

class TabsScreen extends StatefulWidget {
  const TabsScreen({super.key, required this.browser});
  final BrowserController browser;
  @override
  State<TabsScreen> createState() => _TabsScreenState();
}

class _TabsScreenState extends State<TabsScreen> {
  bool _openingTab = false, _creatingTab = false;
  String? _openingTabId;
  int? _countBeforeNewTab, _selectionBeforeNewTab;
  ScrollController? _gridScroll, _listScroll;
  int get _tabCount => _countBeforeNewTab ?? widget.browser.tabs.length;
  bool get grid => widget.browser.store.setting('tabGrid', true) == true;

  Future<void> _openTab([int? index]) async {
    if (_openingTab) return;
    setState(() {
      _openingTab = true;
      _creatingTab = index == null;
      _countBeforeNewTab = widget.browser.tabs.length;
      _selectionBeforeNewTab = widget.browser.selected;
    });
    if (index == null) {
      widget.browser.newTab();
    } else {
      widget.browser.select(index);
    }
    _openingTabId = widget.browser.current.id;
    final thumbnail = widget.browser.current.thumbnail;
    if (thumbnail != null) {
      await precacheImage(MemoryImage(thumbnail), context);
      if (!mounted) return;
    }
    // Lay out the selected page underneath while keeping the tapped card in place.
    await WidgetsBinding.instance.endOfFrame;
    if (mounted && ModalRoute.of(context)?.isCurrent == true) {
      Navigator.pop(context);
    }
  }

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
        CrockPopupMenuButton<String>(
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
                height: 40,
                value: 'reopen',
                child: Text('Reopen closed tab'),
              ),
            const PopupMenuItem(
              height: 40,
              value: 'close',
              child: Text('Close all tabs'),
            ),
          ],
        ),
      ],
      child: AbsorbPointer(
        absorbing: _openingTab,
        child: LayoutBuilder(builder: _tabContent),
      ),
    ),
  );

  Widget _tabContent(BuildContext context, BoxConstraints viewport) {
    final selected = _selectionBeforeNewTab ?? widget.browser.selected;
    if (grid) {
      final rows = (_tabCount + 2) ~/ 2;
      final maximum = (rows * 256.0 + 20 - viewport.maxHeight).clamp(
        0.0,
        double.infinity,
      );
      _gridScroll ??= ScrollController(
        initialScrollOffset: (selected ~/ 2 * 256.0).clamp(0.0, maximum),
      );
      return GridView.builder(
        controller: _gridScroll,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 244,
        ),
        itemCount: _tabCount + 1,
        itemBuilder: (context, index) => _card(index),
      );
    }
    final textScale = MediaQuery.textScalerOf(context);
    final rowHeight =
        (textScale.scale(15) * 1.3 + 4 + textScale.scale(12) * 1.4).clamp(
          48.0,
          double.infinity,
        ) +
        32;
    final maximum = (_tabCount * rowHeight + 84 - viewport.maxHeight).clamp(
      0.0,
      double.infinity,
    );
    _listScroll ??= ScrollController(
      initialScrollOffset: (selected * rowHeight).clamp(0.0, maximum),
    );
    return ListView.builder(
      controller: _listScroll,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _tabCount + 1,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _card(index),
      ),
    );
  }

  @override
  void dispose() {
    _gridScroll?.dispose();
    _listScroll?.dispose();
    super.dispose();
  }

  Widget _card(int index) {
    if (index == _tabCount) {
      return HeroMode(
        enabled: _creatingTab && !MediaQuery.disableAnimationsOf(context),
        child: Hero(
          tag: tabWindowHero(_openingTabId ?? 'new'),
          curve: tabWindowCurve,
          reverseCurve: tabWindowCurve,
          createRectTween: tabWindowRectTween,
          flightShuttleBuilder: homeTabWindowFlight,
          child: _NewTabCard(
            key: const ValueKey('new-tab-card'),
            grid: grid,
            private: widget.browser.privateMode,
            onTap: _openTab,
          ),
        ),
      );
    }
    final tab = widget.browser.tabs[index];
    final card = _TabSwipeDismissible(
      key: ValueKey('dismiss-${tab.id}'),
      tab: tab,
      selected: index == (_selectionBeforeNewTab ?? widget.browser.selected),
      grid: grid,
      showClose: _tabCount > 1,
      onSelect: () => _openTab(index),
      onClose: () => widget.browser.close(index),
      onDismissed: () => widget.browser.close(index),
    );
    return HeroMode(
      key: ValueKey('tab-hero-${tab.id}'),
      enabled:
          !MediaQuery.disableAnimationsOf(context) &&
          (_openingTabId == null
              ? index == widget.browser.selected
              : tab.id == _openingTabId),
      child: grid
          ? card
          : Hero(
              tag: tabWindowHero(tab.id),
              curve: tabWindowCurve,
              reverseCurve: tabWindowCurve,
              createRectTween: tabWindowRectTween,
              flightShuttleBuilder: tabFlightFor(tab),
              child: card,
            ),
    );
  }
}

class _NewTabCard extends StatelessWidget {
  const _NewTabCard({
    super.key,
    required this.grid,
    required this.private,
    required this.onTap,
  });
  final bool grid, private;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final engravedShadows = [
      Shadow(
        color: Colors.black.withValues(alpha: dark ? .65 : .16),
        offset: const Offset(0, -1),
        blurRadius: 1,
      ),
      Shadow(
        color: Colors.white.withValues(alpha: dark ? .12 : .8),
        offset: const Offset(0, 1),
      ),
    ];
    final label = Text(
      private ? 'New private tab' : 'New tab',
      textAlign: grid ? TextAlign.center : TextAlign.start,
      style: Theme.of(context).textTheme.titleMedium
          ?.copyWith(color: colors.onSurfaceVariant, shadows: engravedShadows),
    );
    final icon = Icon(
      Icons.add_rounded,
      size: grid ? 44 : 32,
      color: colors.primary.withValues(alpha: .8),
      shadows: engravedShadows,
    );
    return Semantics(
      button: true,
      child: CustomPaint(
        painter: _EngravedTabBorder(
          fill: Color.lerp(
            Theme.of(context).scaffoldBackgroundColor,
            Colors.black,
            dark ? .14 : .04,
          )!,
          border: colors.outline.withValues(alpha: dark ? .55 : .6),
          dark: dark,
        ),
        child: Material(
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: grid
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [icon, const SizedBox(height: 12), label],
                    )
                  : Row(
                      children: [
                        icon,
                        const SizedBox(width: 8),
                        Expanded(child: label),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EngravedTabBorder extends CustomPainter {
  const _EngravedTabBorder({
    required this.fill,
    required this.border,
    required this.dark,
  });
  final Color fill, border;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(
      rect.deflate(.75),
      const Radius.circular(22),
    );
    canvas.drawRRect(shape, Paint()..color = fill);
    canvas.save();
    canvas.clipRRect(shape);
    // Blur an outside ring into the card, creating inset shadows without elevation.
    void inset(Offset offset, Color color, double blur) {
      final ring = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(rect.inflate(24))
        ..addRRect(shape.shift(offset));
      canvas.drawPath(
        ring,
        Paint()
          ..color = color
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
      );
    }

    inset(
      const Offset(2, 3),
      Colors.black.withValues(alpha: dark ? .6 : .2),
      3,
    );
    inset(
      const Offset(-1, -2),
      Colors.white.withValues(alpha: dark ? .09 : .85),
      2,
    );
    canvas.restore();
    final outline = Path()..addRRect(shape);
    final stroke = Paint()
      ..color = border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final contour in outline.computeMetrics()) {
      for (double distance = 0; distance < contour.length; distance += 11) {
        canvas.drawPath(
          contour.extractPath(
            distance,
            (distance + 6).clamp(0, contour.length),
          ),
          stroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_EngravedTabBorder oldDelegate) =>
      fill != oldDelegate.fill ||
      border != oldDelegate.border ||
      dark != oldDelegate.dark;
}

class _TabSwipeDismissible extends StatefulWidget {
  const _TabSwipeDismissible({
    super.key,
    required this.tab,
    required this.selected,
    required this.grid,
    required this.showClose,
    required this.onSelect,
    required this.onClose,
    required this.onDismissed,
  });

  final BrowserTab tab;
  final bool selected, grid, showClose;
  final VoidCallback onSelect, onClose, onDismissed;

  @override
  State<_TabSwipeDismissible> createState() => _TabSwipeDismissibleState();
}

class _TabSwipeDismissibleState extends State<_TabSwipeDismissible>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  Offset _offset = Offset.zero, _begin = Offset.zero, _target = Offset.zero;
  bool _closing = false;

  double _extent = 1;
  double get _progress => _offset.dx / _extent;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this)
      ..addListener(() {
        setState(
          () => _offset = Offset.lerp(
            _begin,
            _target,
            AppMotion.curve.transform(_motion.value),
          )!,
        );
      });
  }

  void _drag(DragUpdateDetails details) {
    if (_closing) return;
    _motion.stop();
    _extent = context.size?.width ?? 1;
    setState(() {
      _offset = Offset(
        (_offset.dx + details.delta.dx).clamp(0.0, double.infinity),
        0,
      );
    });
  }

  Future<void> _settle(double velocity) async {
    if (_closing) return;
    final dismiss = _progress >= .22 || velocity > 700;
    _closing = dismiss;
    _begin = _offset;
    _target = dismiss ? Offset(_extent, 0) : Offset.zero;
    _motion.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AnimationTimings.tabSwipe;
    try {
      await _motion.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (mounted && dismiss) widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onHorizontalDragUpdate: _drag,
    onHorizontalDragEnd: (details) => _settle(details.primaryVelocity ?? 0),
    onHorizontalDragCancel: () => _settle(0),
    child: Transform.translate(
      offset: _offset,
      child: Opacity(
        opacity: _offset == Offset.zero ? 1 : (1 - _progress).clamp(0.0, 1.0),
        child: BrowserTabCard(
          showClose: widget.showClose,
          previewHero: widget.grid,
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
