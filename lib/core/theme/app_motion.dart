import 'package:flutter/material.dart';

import 'animation_timings.dart';

/// A single symmetric easy-ease curve for application transitions.
/// Controllers use elapsed time and display vsync; no frame count or Hz target.
abstract final class AppMotion {
  static const Curve curve = Curves.easeInOut;
}

class EasyEasePageTransitionsBuilder extends PageTransitionsBuilder {
  const EasyEasePageTransitionsBuilder();

  @override
  Duration get transitionDuration => AnimationTimings.pageEnter;

  @override
  Duration get reverseTransitionDuration => AnimationTimings.pageExit;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: AppMotion.curve)).animate(animation),
      textDirection: Directionality.of(context),
      child: child,
    );
  }
}
