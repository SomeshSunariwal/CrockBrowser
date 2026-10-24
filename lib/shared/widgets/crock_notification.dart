import 'dart:async';

import 'package:flutter/material.dart';

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
              duration: Duration(milliseconds: reduceMotion ? 0 : 240),
              reverseDuration: Duration(milliseconds: reduceMotion ? 0 : 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
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

class _SwipeNotificationState extends State<_SwipeNotification> {
  double _opacity = 1;

  @override
  Widget build(BuildContext context) => Dismissible(
    key: const ValueKey('notification-swipe'),
    direction: DismissDirection.up,
    resizeDuration: null,
    movementDuration: Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 180,
    ),
    dismissThresholds: const {DismissDirection.up: .25},
    onUpdate: (details) =>
        setState(() => _opacity = 1 - details.progress.clamp(0.0, 1.0)),
    onDismissed: (_) => widget.onDismissed(),
    child: Opacity(opacity: _opacity, child: widget.child),
  );
}
