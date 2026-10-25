import 'package:flutter/material.dart';

import '../../../core/models/browser_tab.dart';

const tabPreviewHeroKey = ValueKey('tab-window-preview');
const tabPreviewCorners = BorderRadius.vertical(top: Radius.circular(16));

HeroFlightShuttleBuilder tabFlightFor(BrowserTab tab) => tab.atHome
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
    _TabWindowRectTween(begin: begin, end: end);

class _TabWindowRectTween extends RectTween {
  _TabWindowRectTween({super.begin, super.end});

  @override
  Rect? lerp(double t) => super.lerp(Curves.easeOutCubic.transform(t));
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
  final size = (pageContext.findRenderObject()! as RenderBox).size;
  final home = MediaQuery(
    data: MediaQuery.of(pageContext),
    child: Theme(data: Theme.of(pageContext), child: destination.child),
  );
  return _tabFlight(
    animation,
    direction,
    from,
    to,
    page: FittedBox(
      fit: BoxFit.fitWidth,
      alignment: Alignment.topCenter,
      child: SizedBox(width: size.width, height: size.height, child: home),
    ),
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
  return _tabFlight(
    animation,
    direction,
    from,
    to,
    page: Material(
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
  );
}

Widget _tabFlight(
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext from,
  BuildContext to, {
  required Widget page,
}) {
  final card =
      (direction == HeroFlightDirection.push ? to : from).widget as Hero;
  final corners = card.key == tabPreviewHeroKey
      ? tabPreviewCorners
      : BorderRadius.circular(22);
  return AnimatedBuilder(
    animation: animation,
    child: page,
    builder: (_, child) {
      final entering = direction == HeroFlightDirection.push;
      // Hero geometry reverses pop animations internally, but the shuttle gets
      // the route's original animation (1 -> 0). Normalize it for visual effects.
      final progress = entering ? animation.value : 1 - animation.value;
      final cardProgress = entering
          ? const Interval(
              .55,
              1,
              curve: Curves.easeOutCubic,
            ).transform(progress)
          : 1 -
                const Interval(
                  0,
                  .45,
                  curve: Curves.easeOutCubic,
                ).transform(progress);
      return ClipRRect(
        key: const ValueKey('tab-window-flight'),
        borderRadius: BorderRadius.lerp(
          BorderRadius.zero,
          corners,
          entering ? progress : 1 - progress,
        )!,
        child: Stack(
          fit: StackFit.expand,
          children: [
            child!,
            // Blend into the exact card preview, so its final paint matches the
            // last zoom frame instead of swapping images when the Hero disappears.
            Opacity(
              key: const ValueKey('tab-card-flight-artwork'),
              opacity: cardProgress,
              child: card.child,
            ),
          ],
        ),
      );
    },
  );
}
