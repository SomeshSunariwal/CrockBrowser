import 'package:flutter/material.dart';

import 'crock_logo.dart';
import 'crock_notification.dart';

class FeatureScaffold extends StatelessWidget {
  const FeatureScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });
  final String title;
  final Widget child;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    body: SafeArea(top: false, child: child),
  );
}

class CrockEmpty extends StatelessWidget {
  const CrockEmpty({
    super.key,
    required this.title,
    required this.detail,
    this.action,
  });
  final String title, detail;
  final Widget? action;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CrockLogo(size: 64),
                const SizedBox(height: 22),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                if (action != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: action!,
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void crockMessage(BuildContext context, Object message) {
  if (!context.mounted) return;
  crockNotification.value = message.toString();
}

Future<bool> confirmCrock(
  BuildContext context,
  String title,
  String message,
) async =>
    await showCrockDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    ) ??
    false;

String byteLabel(num bytes) {
  if (bytes < 0) return 'Unknown size';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
}

/// Wait until the route has unmounted before callers dispose local editor controllers.
void dismissCrockRoute<T>(BuildContext context, [T? result]) {
  final route = ModalRoute.of<T>(context);
  if (route == null) return;
  final navigator = Navigator.of(context);
  if (route.isCurrent) {
    navigator.pop(result);
  } else {
    // A notification may have opened another screen while an operation was awaiting.
    navigator.removeRoute(route, result);
  }
}

Future<T?> showCrockDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = DialogRoute<T>(
    context: context,
    builder: builder,
    barrierDismissible: barrierDismissible,
    themes: InheritedTheme.capture(from: context, to: navigator.context),
  );
  final result = await navigator.push(route);
  await route.completed;
  return result;
}

Future<T?> showCrockSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool showDragHandle = true,
}) async {
  final navigator = Navigator.of(context);
  final theme = Theme.of(context);
  final route = ModalBottomSheetRoute<T>(
    sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: Duration(milliseconds: 280),
            reverseDuration: Duration(milliseconds: 200),
          ),
    builder: builder,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    capturedThemes: InheritedTheme.capture(
      from: context,
      to: navigator.context,
    ),
    showDragHandle:
        showDragHandle && (theme.bottomSheetTheme.showDragHandle ?? false),
    modalBarrierColor: theme.bottomSheetTheme.modalBarrierColor,
  );
  final result = await navigator.push(route);
  await route.completed;
  return result;
}
