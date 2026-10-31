import 'package:flutter/material.dart';

import '../../../core/models/browser_tab.dart';
import '../../../core/theme/app_motion.dart';

const tabPreviewHeroKey = ValueKey('tab-window-preview');
const tabPreviewCorners = BorderRadius.vertical(top: Radius.circular(16));
const tabWindowCurve = AppMotion.curve;

HeroFlightShuttleBuilder tabFlightFor(BrowserTab tab) =>
    // Keep vector dashboard icons throughout the zoom. Enlarging the small
    // card thumbnail and swapping to live artwork at the end causes a flash.
    tab.atHome
    ? homeTabWindowFlight
    : (context, animation, direction, from, to) => tabPreviewFlight(
        context,
        animation,
        direction,
        from,
        to,
        preview: tab.thumbnail == null ? null : MemoryImage(tab.thumbnail!),
      );

String tabWindowHero(String id) => 'crock-tab-window:$id';

RectTween tabWindowRectTween(Rect? begin, Rect? end) =>
    // Hero already curves its animation. Curving the rectangle again makes the
    // zoom race ahead of the artwork and almost stop before the route settles.
    RectTween(begin: begin, end: end);

/// Lay out the artwork once, then scale its retained layer during the flight.
/// In particular, don't reflow the home page at every intermediate Hero size.
Widget _flightArtwork(BuildContext context, Widget child) {
  final size = (context.findRenderObject()! as RenderBox).size;
  return FittedBox(
    fit: BoxFit.fitWidth,
    alignment: Alignment.topCenter,
    child: RepaintBoundary(
      child: SizedBox(width: size.width, height: size.height, child: child),
    ),
  );
}

Widget homeTabWindowFlight(
  BuildContext context,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext from,
  BuildContext to,
) {
  final pageContext = direction == HeroFlightDirection.push ? from : to;
  final destination = pageContext.widget as Hero;
  final home = MediaQuery(
    data: MediaQuery.of(pageContext),
    child: Theme(data: Theme.of(pageContext), child: destination.child),
  );
  return _tabFlight(
    animation,
    direction,
    from,
    to,
    page: _flightArtwork(pageContext, home),
  );
}

/// A native WebView must stay in its original tree. Fly its saved viewport image
/// instead of constructing another platform view in the transition overlay.
Widget tabPreviewFlight(
  BuildContext context,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext from,
  BuildContext to, {
  required ImageProvider? preview,
}) {
  final colors = Theme.of(context).colorScheme;
  final pageContext = direction == HeroFlightDirection.push ? from : to;
  return _tabFlight(
    animation,
    direction,
    from,
    to,
    page: _flightArtwork(
      pageContext,
      Material(
        color: colors.surface,
        child: preview == null
            ? Center(
                child: Icon(
                  Icons.public_rounded,
                  color: colors.onSurfaceVariant,
                  size: 44,
                ),
              )
            : Image(
                image: preview,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topCenter,
                gaplessPlayback: true,
              ),
      ),
    ),
  );
}

Widget _tabFlight(
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext from,
  BuildContext to, {
  required Widget page,
}) {
  final cardContext = direction == HeroFlightDirection.push ? to : from;
  final card = cardContext.widget as Hero;
  final corners = card.key == tabPreviewHeroKey
      ? tabPreviewCorners
      : BorderRadius.circular(22);
  return AnimatedBuilder(
    animation: animation,
    child: page,
    builder: (_, child) {
      // Only one page image flies. Blending an enlarged card over it doubles
      // artwork and scales card controls into the middle of the webpage.
      final cardProgress = animation.value;
      return ClipRRect(
        key: const ValueKey('tab-window-flight'),
        borderRadius: BorderRadius.lerp(
          BorderRadius.zero,
          corners,
          cardProgress,
        )!,
        child: child,
      );
    },
  );
}
