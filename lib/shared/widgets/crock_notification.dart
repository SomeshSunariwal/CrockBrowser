import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/animation_timings.dart';
import '../../core/theme/app_motion.dart';

class CrockNotification {
  const CrockNotification(this.message, {this.actionLabel, this.onAction});
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
}

final crockNotification = ValueNotifier<CrockNotification?>(null);
final crockNotificationObscured = ValueNotifier<bool>(false);
final crockAddressBarKey = GlobalKey();

class CrockNotificationHost extends StatefulWidget {
  const CrockNotificationHost({super.key, required this.child});
  final Widget child;

  @override
  State<CrockNotificationHost> createState() => _CrockNotificationHostState();
}

class _CrockNotificationHostState extends State<CrockNotificationHost> {
  Timer? _dismissTimer;
  int _version = 0;

  @override
  void initState() {
    super.initState();
    crockNotification.addListener(_changed);
    crockNotificationObscured.addListener(_visibilityChanged);
  }

  void _visibilityChanged() => setState(() {});

  void _changed() {
    _dismissTimer?.cancel();
    if (crockNotification.value != null) {
      _dismissTimer = Timer(const Duration(seconds: 4), () {
        crockNotification.value = null;
      });
    }
    setState(() => _version++);
  }

  @override
  void dispose() {
    crockNotification.removeListener(_changed);
    crockNotificationObscured.removeListener(_visibilityChanged);
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anchor = crockAddressBarKey.currentContext;
    final box = anchor?.findRenderObject();
    final top =
        box is RenderBox &&
            box.hasSize &&
            ModalRoute.of(anchor!)?.isCurrent == true
        ? box.localToGlobal(Offset(0, box.size.height)).dy
        : MediaQuery.paddingOf(context).top + kToolbarHeight;
    final message = crockNotification.value;
    final version = _version;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: top + 8,
          left: 12,
          right: 12,
          child: Offstage(
            offstage: crockNotificationObscured.value,
            child: AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : AnimationTimings.notificationSlideIn,
              reverseDuration: reduceMotion
                  ? Duration.zero
                  : AnimationTimings.notificationSlideOut,
              switchInCurve: AppMotion.curve,
              switchOutCurve: AppMotion.curve,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -.15),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: message == null
                  ? const SizedBox.shrink()
                  : _SwipeNotification(
                      key: ValueKey(_version),
                      onDismissed: () {
                        if (_version == version) crockNotification.value = null;
                      },
                      child: Material(
                        elevation: 8,
                        shadowColor: Colors.black26,
                        color: Theme.of(context).colorScheme.inverseSurface,
                        borderRadius: BorderRadius.circular(16),
                        child: Semantics(
                          liveRegion: true,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: 16,
                              top: 4,
                              bottom: 4,
                              right: 4,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    message.message,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onInverseSurface,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                if (message.actionLabel != null &&
                                    message.onAction != null)
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: Theme.of(context)
                                          .colorScheme
                                          .inversePrimary,
                                    ),
                                    onPressed: () {
                                      if (_version != version) return;
                                      crockNotification.value = null;
                                      message.onAction!();
                                    },
                                    child: Text(message.actionLabel!),
                                  )
                                else
                                  IconButton(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onInverseSurface,
                                    onPressed: () =>
                                        crockNotification.value = null,
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 20,
                                      semanticLabel: 'Dismiss notification',
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SwipeNotification extends StatefulWidget {
  const _SwipeNotification({
    super.key,
    required this.child,
    required this.onDismissed,
  });
  final Widget child;
  final VoidCallback onDismissed;

  @override
  State<_SwipeNotification> createState() => _SwipeNotificationState();
}

class _SwipeNotificationState extends State<_SwipeNotification>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  double _offset = 0, _begin = 0, _target = 0;
  bool _dismissing = false;
  double _extent = 1;

  @override
  void initState() {
    super.initState();
    _motion = AnimationController(vsync: this)
      ..addListener(
        () => setState(() {
          final progress = AppMotion.curve.transform(_motion.value);
          _offset = _begin + (_target - _begin) * progress;
        }),
      );
  }

  Future<void> _settle(double velocity) async {
    if (_dismissing) return;
    final dismiss = -_offset / _extent >= .25 || velocity < -700;
    _dismissing = dismiss;
    _begin = _offset;
    _target = dismiss ? -_extent : 0;
    _motion.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AnimationTimings.notificationSwipe;
    try {
      await _motion.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    if (mounted && dismiss) widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    onDismiss: widget.onDismissed,
    child: GestureDetector(
      key: const ValueKey('notification-swipe'),
      onVerticalDragUpdate: (details) {
        if (_dismissing) return;
        _motion.stop();
        _extent = (context.size?.height ?? 1).clamp(1.0, double.infinity);
        setState(
          () => _offset = (_offset + details.delta.dy).clamp(-_extent, 0.0),
        );
      },
      onVerticalDragEnd: (details) => _settle(details.primaryVelocity ?? 0),
      onVerticalDragCancel: () => _settle(0),
      child: Transform.translate(
        offset: Offset(0, _offset),
        child: Opacity(
          opacity: (1 + _offset / _extent).clamp(0.0, 1.0),
          child: widget.child,
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
