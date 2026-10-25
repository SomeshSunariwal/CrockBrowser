import 'package:crockbrowser/features/tabs/widgets/tab_window_transition.dart';
import 'package:crockbrowser/core/theme/animation_timings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final preview in [false, true]) {
    for (final hz in [60, 90, 120]) {
      testWidgets(
        '${preview ? 'Web preview' : 'Home'} flight uses one timeline at $hz Hz',
        (tester) async {
          final pageLayouts = <Size>[];
          final cardLayouts = <Size>[];
          final navigator = GlobalKey<NavigatorState>();
          Widget artwork(List<Size> layouts) => LayoutBuilder(
            builder: (_, constraints) {
              layouts.add(constraints.biggest);
              return const SizedBox.expand(
                child: ColoredBox(color: Colors.blue),
              );
            },
          );
          Widget hero({required bool card}) => Hero(
            key: card ? tabPreviewHeroKey : null,
            tag: tabWindowHero('test'),
            curve: tabWindowCurve,
            reverseCurve: tabWindowCurve,
            createRectTween: tabWindowRectTween,
            flightShuttleBuilder: preview
                ? (context, animation, direction, from, to) => tabPreviewFlight(
                    context,
                    animation,
                    direction,
                    from,
                    to,
                    preview: null,
                  )
                : homeTabWindowFlight,
            child: artwork(card ? cardLayouts : pageLayouts),
          );
          await tester.pumpWidget(
            MaterialApp(
              navigatorKey: navigator,
              home: Scaffold(body: hero(card: false)),
            ),
          );
          final pageSize = pageLayouts.single;
          navigator.currentState!.push(
            PageRouteBuilder<void>(
              transitionDuration: AnimationTimings.tabOverview,
              reverseTransitionDuration: AnimationTimings.tabOverview,
              pageBuilder: (_, _, _) => Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 160,
                    height: 220,
                    child: hero(card: true),
                  ),
                ),
              ),
            ),
          );
          Future<void> sampleMotion() async {
            final interval = Duration(microseconds: (1000000 / hz).round());
            for (var frame = 0; frame < (hz * .12).round(); frame++) {
              await tester.pump(interval);
            }
            final flight = find.byKey(const ValueKey('tab-window-flight'));
            final width = tester.getSize(flight).width;
            final progress = (pageSize.width - width) / (pageSize.width - 160);
            final clip = tester.widget<ClipRRect>(flight);
            expect(
              find.byKey(const ValueKey('tab-card-flight-artwork')),
              findsNothing,
            );
            expect(
              (clip.borderRadius as BorderRadius).topLeft.x,
              closeTo(16 * progress, .0001),
            );
          }

          await tester.pump();
          await sampleMotion();
          expect(
            find.byKey(const ValueKey('tab-window-flight')),
            findsOneWidget,
          );
          await tester.pump(const Duration(milliseconds: 70));
          // Hero keeps the original child offstage at zero size while flying.
          expect(pageLayouts.where((size) => !size.isEmpty).toSet(), {
            pageSize,
          });
          expect(
            cardLayouts.every(
              (size) => size.isEmpty || size == const Size(160, 220),
            ),
            isTrue,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpAndSettle();

          navigator.currentState!.pop();
          await tester.pump();
          await sampleMotion();
          expect(
            find.byKey(const ValueKey('tab-window-flight')),
            findsOneWidget,
          );
          expect(pageLayouts.where((size) => !size.isEmpty).toSet(), {
            pageSize,
          });
          expect(
            cardLayouts.every(
              (size) => size.isEmpty || size == const Size(160, 220),
            ),
            isTrue,
          );
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('tab-window-flight')), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
