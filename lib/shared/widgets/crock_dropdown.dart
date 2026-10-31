import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_motion.dart';

/// All menus reveal at their full width, vertically from their top edge.
class CrockPopupMenuButton<T> extends PopupMenuButton<T> {
  const CrockPopupMenuButton({
    super.key,
    required super.itemBuilder,
    super.initialValue,
    super.onOpened,
    super.onCanceled,
    super.onSelected,
    super.tooltip,
    super.elevation,
    super.padding = EdgeInsets.zero,
    super.child,
    super.icon,
    super.iconSize = 20,
    super.offset,
    super.enabled,
    super.shape,
    super.color,
    super.surfaceTintColor,
    super.shadowColor,
    super.constraints,
    super.position,
    super.clipBehavior,
    super.menuPadding,
    this.matchAnchorWidth = false,
  });

  final bool matchAnchorWidth;

  @override
  PopupMenuButtonState<T> createState() => _CrockPopupMenuButtonState<T>();
}

class _CrockPopupMenuButtonState<T> extends PopupMenuButtonState<T> {
  bool _open = false;

  @override
  Future<void> showButtonMenu() async {
    if (_open || !widget.enabled) return;
    final entries = widget.itemBuilder(context);
    if (entries.isEmpty) return;
    final navigator = Navigator.of(context);
    final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
    final button = context.findRenderObject()! as RenderBox;
    final anchor =
        button.localToGlobal(Offset.zero, ancestor: overlay) & button.size;
    final theme = PopupMenuTheme.of(context);
    final route = _VerticalMenuRoute<T>(
      entries: entries,
      anchor: anchor.shift(widget.offset),
      below:
          (widget.position ?? theme.position ?? PopupMenuPosition.over) ==
          PopupMenuPosition.under,
      themes: InheritedTheme.capture(from: context, to: navigator.context),
      color: widget.color ?? theme.color,
      elevation: widget.elevation ?? theme.elevation ?? 6,
      shape: widget.shape ?? theme.shape,
      shadowColor: widget.shadowColor ?? theme.shadowColor,
      surfaceTintColor: widget.surfaceTintColor ?? theme.surfaceTintColor,
      constraints: (widget as CrockPopupMenuButton<T>).matchAnchorWidth
          ? BoxConstraints.tightFor(width: button.size.width)
          : widget.constraints,
      menuPadding:
          widget.menuPadding ??
          theme.menuPadding ??
          const EdgeInsets.symmetric(vertical: 2),
      clip: widget.clipBehavior,
      reduceMotion: MediaQuery.disableAnimationsOf(context),
    );
    _open = true;
    widget.onOpened?.call();
    final result = await navigator.push<T>(route);
    _open = false;
    if (!mounted) return;
    if (result == null) {
      widget.onCanceled?.call();
    } else {
      widget.onSelected?.call(result);
    }
  }
}

class _VerticalMenuRoute<T> extends PopupRoute<T> {
  _VerticalMenuRoute({
    required this.entries,
    required this.anchor,
    required this.below,
    required this.themes,
    required this.color,
    required this.elevation,
    required this.shape,
    required this.shadowColor,
    required this.surfaceTintColor,
    required this.constraints,
    required this.menuPadding,
    required this.clip,
    required this.reduceMotion,
  });

  final List<PopupMenuEntry<T>> entries;
  final Rect anchor;
  final bool below, reduceMotion;
  final CapturedThemes themes;
  final Color? color, shadowColor, surfaceTintColor;
  final double elevation;
  final ShapeBorder? shape;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry menuPadding;
  final Clip clip;

  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 200);
  @override
  Duration get reverseTransitionDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 140);
  @override
  bool get barrierDismissible => true;
  @override
  Color? get barrierColor => null;
  @override
  String get barrierLabel => 'Dismiss menu';

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final media = MediaQuery.of(context);
    final progress = animation.drive(CurveTween(curve: AppMotion.curve));
    return themes.wrap(
      CustomSingleChildLayout(
        delegate: _MenuLayout(
          anchor,
          below,
          media.padding,
          constraints,
          Directionality.of(context),
        ),
        child: ClipRect(
          key: const ValueKey('dropdown-vertical-reveal'),
          clipper: _VerticalReveal(progress),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Material(
              color: color ?? Theme.of(context).colorScheme.surface,
              elevation: elevation,
              shadowColor: shadowColor,
              surfaceTintColor: surfaceTintColor,
              shape:
                  shape ??
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
              clipBehavior: clip == Clip.none ? Clip.antiAlias : clip,
              child: Semantics(
                role: SemanticsRole.menu,
                scopesRoute: true,
                namesRoute: true,
                label: MaterialLocalizations.of(context).popupMenuLabel,
                explicitChildNodes: true,
                child: FocusScope(
                  autofocus: true,
                  child: Shortcuts(
                    shortcuts: const <ShortcutActivator, Intent>{
                      SingleActivator(LogicalKeyboardKey.escape):
                          DismissIntent(),
                    },
                    child: Actions(
                      actions: <Type, Action<Intent>>{
                        DismissIntent: CallbackAction<DismissIntent>(
                          onInvoke: (_) {
                            Navigator.of(context).pop();
                            return null;
                          },
                        ),
                      },
                      child: IntrinsicWidth(
                        stepWidth: 56,
                        child: SingleChildScrollView(
                          padding: menuPadding,
                          child: PopupMenuTheme(
                            data: PopupMenuTheme.of(context).copyWith(
                              labelTextStyle: WidgetStateProperty.resolveWith(
                                (states) => TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  height: 1.2,
                                  color: Theme.of(context).colorScheme.onSurface
                                      .withValues(
                                        alpha:
                                            states.contains(
                                              WidgetState.disabled,
                                            )
                                            ? .38
                                            : 1,
                                      ),
                                ),
                              ),
                            ),
                            child: ListBody(children: entries),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VerticalReveal extends CustomClipper<Rect> {
  _VerticalReveal(this.progress) : super(reclip: progress);
  final Animation<double> progress;
  @override
  Rect getClip(Size size) {
    // Include the material shadow outside the panel's layout bounds.
    // The reveal still moves only vertically, with no horizontal scaling.
    const shadowSpace = 24.0;
    return Rect.fromLTWH(
      -shadowSpace,
      -shadowSpace,
      size.width + shadowSpace * 2,
      (size.height + shadowSpace * 2) * progress.value,
    );
  }

  @override
  bool shouldReclip(_VerticalReveal oldClipper) =>
      oldClipper.progress != progress;
}

class _MenuLayout extends SingleChildLayoutDelegate {
  _MenuLayout(
    this.anchor,
    this.below,
    this.padding,
    this.menuConstraints,
    this.direction,
  );
  final Rect anchor;
  final bool below;
  final EdgeInsets padding;
  final BoxConstraints? menuConstraints;
  final TextDirection direction;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final available = BoxConstraints(
      maxWidth: (constraints.maxWidth - padding.horizontal - 16).clamp(
        0,
        double.infinity,
      ),
      maxHeight: (constraints.maxHeight - padding.vertical - 16).clamp(
        0,
        double.infinity,
      ),
    );
    final desired =
        menuConstraints ?? const BoxConstraints(minWidth: 112, maxWidth: 280);
    // The eight-pixel outer gutter reserves room for the shadow.
    return BoxConstraints(
      minWidth: desired.minWidth + 16,
      maxWidth: desired.maxWidth + 16,
      minHeight: desired.minHeight,
      maxHeight: desired.maxHeight,
    ).enforce(available);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final rightAligned = anchor.center.dx > size.width / 2;
    final left = rightAligned
        ? anchor.right - childSize.width + 8
        : anchor.left - 8;
    final top = (below ? anchor.bottom : anchor.top) - 8;
    return Offset(
      left.clamp(
        padding.left + 8,
        size.width - padding.right - childSize.width - 8,
      ),
      top.clamp(
        padding.top + 8,
        size.height - padding.bottom - childSize.height - 8,
      ),
    );
  }

  @override
  bool shouldRelayout(_MenuLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      below != oldDelegate.below ||
      padding != oldDelegate.padding ||
      menuConstraints != oldDelegate.menuConstraints ||
      direction != oldDelegate.direction;
}

class CrockDropdownButton<T> extends StatelessWidget {
  const CrockDropdownButton({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.isDense = false,
    this.isExpanded = false,
    this.style,
    this.borderRadius,
    this.itemIcons,
  });
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool isDense, isExpanded;
  final TextStyle? style;
  final BorderRadius? borderRadius;
  final Map<T, IconData>? itemIcons;

  @override
  Widget build(BuildContext context) {
    final selected = items.where((item) => item.value == value);
    return CrockPopupMenuButton<T>(
      enabled: onChanged != null,
      position: PopupMenuPosition.under,
      initialValue: value,
      matchAnchorWidth: isExpanded,
      menuPadding: const EdgeInsets.symmetric(vertical: 6),
      offset: const Offset(0, 5),
      constraints: const BoxConstraints.tightFor(width: 160),
      shape: borderRadius == null
          ? null
          : RoundedRectangleBorder(
              borderRadius: borderRadius!,
              side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
                width: 1,
              ),
            ),
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final item in items)
          PopupMenuItem<T>(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            value: item.value,
            enabled: item.enabled,
            child: DefaultTextStyle.merge(
              style: TextStyle(
                color: item.value == value
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: item.value == value
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
              child: Row(
                children: [
                  if (itemIcons?[item.value] case final icon?) ...[
                    Icon(
                      icon,
                      size: 18,
                      color: item.value == value
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(child: item.child),
                  if (item.value == value) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
      child: DefaultTextStyle(
        style: style ?? Theme.of(context).textTheme.bodyMedium!,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 8,
            vertical: isDense ? 4 : 8,
          ),
          child: Row(
            mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (isExpanded)
                Expanded(
                  child: selected.isEmpty
                      ? const SizedBox()
                      : selected.first.child,
                )
              else if (selected.isNotEmpty)
                selected.first.child,
              const SizedBox(width: 8),
              const Icon(Icons.arrow_drop_down_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class CrockDropdownButtonFormField<T> extends FormField<T> {
  CrockDropdownButtonFormField({
    super.key,
    super.initialValue,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    InputDecoration decoration = const InputDecoration(),
  }) : super(
         builder: (state) => InputDecorator(
           decoration: decoration,
           isEmpty: state.value == null,
           child: CrockDropdownButton<T>(
             value: state.value,
             items: items,
             isDense: true,
             isExpanded: true,
             onChanged: (value) {
               state.didChange(value);
               onChanged(value);
             },
           ),
         ),
       );
}
