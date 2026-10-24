import 'package:flutter/material.dart';

/// Keep browser chrome outside the preview Hero and use the overview's timeline.
/// Rebuilding a home tab must not restart a separate entrance animation.
class TabToolbarTransition extends StatelessWidget {
  const TabToolbarTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  final Widget child;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (_, child) {
        final progress =
            1 -
            const Interval(
              0,
              .65,
              curve: Curves.easeInCubic,
            ).transform(animation.value);
        return IgnorePointer(
          ignoring: animation.value != 0,
          child: Opacity(
            key: const ValueKey('tab-toolbar-fade'),
            opacity: progress,
            child: Transform.translate(
              key: const ValueKey('tab-toolbar-slide'),
              offset: Offset(0, 24 * (1 - progress)),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
