import 'package:flutter/material.dart';

/// A single symmetric easy-ease curve for application transitions.
/// Controllers use elapsed time and display vsync; no frame count or Hz target.
abstract final class AppMotion {
  static const Curve curve = Curves.easeInOut;
}

class EasyEasePageTransitionsBuilder extends PageTransitionsBuilder {
  const EasyEasePageTransitionsBuilder();

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
        begin: const Offset(.08, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: AppMotion.curve)).animate(animation),
      child: child,
    );
  }
}
