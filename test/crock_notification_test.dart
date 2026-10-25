import 'package:crockbrowser/shared/widgets/crock_notification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final reducedMotion in [false, true]) {
    testWidgets(
      'notification swipe settles and dismisses (reduced=$reducedMotion)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reducedMotion),
              child: const CrockNotificationHost(child: Scaffold()),
            ),
          ),
        );
        crockNotification.value = const CrockNotification('Download ready');
        await tester.pumpAndSettle();
        final notification = find.byKey(const ValueKey('notification-swipe'));
        await tester.timedDrag(
          notification,
          const Offset(0, -8),
          const Duration(milliseconds: 500),
        );
        await tester.pumpAndSettle();
        expect(crockNotification.value?.message, 'Download ready');
        await tester.drag(notification, const Offset(0, -100));
        await tester.pumpAndSettle();
        expect(crockNotification.value, isNull);
        expect(find.text('Download ready'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
