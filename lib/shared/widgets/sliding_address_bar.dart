import 'package:flutter/material.dart';

/// Keeps the toolbar at its natural size while translating it through the top edge.
class SlidingAddressBar extends StatelessWidget {
  const SlidingAddressBar({
    super.key,
    required this.visibility,
    required this.child,
  });
  final Animation<double> visibility;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: visibility,
    child: RepaintBoundary(child: child),
    builder: (context, child) => ClipRect(
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: visibility.value,
        child: FractionalTranslation(
          translation: Offset(0, visibility.value - 1),
          child: IgnorePointer(ignoring: visibility.value == 0, child: child),
        ),
      ),
    ),
  );
}
