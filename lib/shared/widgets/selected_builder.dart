import 'package:flutter/widgets.dart';

/// A projection suitable for merging with other listenables without forwarding
/// unrelated source changes (for example, brightness while scrolling Settings).
class SelectedValue<T> extends ValueNotifier<T> {
  SelectedValue(this.source, this.select) : super(select()) {
    source.addListener(_refresh);
  }
  final Listenable source;
  final T Function() select;
  void _refresh() => value = select();
  @override
  void dispose() {
    source.removeListener(_refresh);
    super.dispose();
  }
}

/// Rebuilds only when the selected value changes, rather than on every event.
class SelectedBuilder<T> extends StatefulWidget {
  const SelectedBuilder({
    super.key,
    required this.listenable,
    required this.select,
    required this.builder,
  });
  final Listenable listenable;
  final T Function() select;
  final Widget Function(BuildContext, T) builder;
  @override
  State<SelectedBuilder<T>> createState() => _SelectedBuilderState<T>();
}

class _SelectedBuilderState<T> extends State<SelectedBuilder<T>> {
  late T _value;
  @override
  void initState() {
    super.initState();
    _value = widget.select();
    widget.listenable.addListener(_changed);
  }

  void _changed() {
    final next = widget.select();
    if (next != _value) setState(() => _value = next);
  }

  @override
  void didUpdateWidget(covariant SelectedBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listenable != oldWidget.listenable) {
      oldWidget.listenable.removeListener(_changed);
      widget.listenable.addListener(_changed);
    }
    _value = widget.select();
  }

  @override
  void dispose() {
    widget.listenable.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _value);
}
