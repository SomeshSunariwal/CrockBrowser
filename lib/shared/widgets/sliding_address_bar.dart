import 'package:flutter/material.dart';

/// Moving browser chrome must not resize the native WebView on every frame.
/// A stable viewport avoids page reflow and resize-induced scroll callbacks.
class StableBrowserViewport extends StatelessWidget {
  const StableBrowserViewport({
    super.key,
    required this.height,
    required this.child,
  });
  final double? height;
  final Widget child;

  @override
  Widget build(BuildContext context) => height == null
      ? child
      : ClipRect(
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: height,
            maxHeight: height,
            child: child,
          ),
        );
}

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
