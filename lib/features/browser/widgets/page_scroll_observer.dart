import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Observe without competing with WebView gestures. Global Flutter coordinates
/// stay stable when the native view is translated by the collapsing toolbar.
class PageScrollObserver extends StatefulWidget {
  const PageScrollObserver({
    super.key,
    required this.onScroll,
    required this.child,
  });
  final ValueChanged<double> onScroll;
  final Widget child;

  @override
  State<PageScrollObserver> createState() => _PageScrollObserverState();
}

class _PageScrollObserverState extends State<PageScrollObserver> {
  final _pointers = <int>{};
  Offset? _start, _last;
  bool _vertical = false;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (event) {
      _pointers.add(event.pointer);
      _vertical = false;
      _start = _last = _pointers.length == 1 ? event.position : null;
    },
    onPointerMove: (event) {
      final start = _start, last = _last;
      if (_pointers.length != 1 || start == null || last == null) return;
      final movement = event.position - start;
      _last = event.position;
      if (!_vertical &&
          movement.dy.abs() > kTouchSlop &&
          movement.dy.abs() > movement.dx.abs()) {
        _vertical = true;
      }
      if (_vertical) widget.onScroll(last.dy - event.position.dy);
    },
    onPointerUp: (event) => _pointers.remove(event.pointer),
    onPointerCancel: (event) => _pointers.remove(event.pointer),
    onPointerSignal: (event) {
      if (event is PointerScrollEvent) widget.onScroll(event.scrollDelta.dy);
    },
    child: widget.child,
  );
}
