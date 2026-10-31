import 'package:flutter/material.dart';

import '../../../core/theme/animation_timings.dart';
import '../../../core/theme/app_motion.dart';
import 'settings_components.dart';

/// Retains the body during its closing animation, then releases hidden controls.
class ExpandableSettingsRow extends StatefulWidget {
  const ExpandableSettingsRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.builder,
  });
  final IconData icon;
  final String title, subtitle;
  final WidgetBuilder builder;

  @override
  State<ExpandableSettingsRow> createState() => _ExpandableSettingsRowState();
}

class _ExpandableSettingsRowState extends State<ExpandableSettingsRow> {
  final _controller = ExpansibleController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Expansible(
    controller: _controller,
    maintainState: false,
    animationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: AnimationTimings.inlineExpand,
            curve: AppMotion.curve,
          ),
    headerBuilder: (context, animation) => Semantics(
      expanded: _controller.isExpanded,
      child: SettingsRow(
        icon: widget.icon,
        title: widget.title,
        subtitle: widget.subtitle,
        trailing: RotationTransition(
          turns: animation
              .drive(CurveTween(curve: AppMotion.curve))
              .drive(Tween<double>(begin: 0, end: .5)),
          child: Icon(
            Icons.expand_more_rounded,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        onTap: _controller.toggle,
      ),
    ),
    bodyBuilder: (context, animation) => SlideTransition(
      position: animation
          .drive(CurveTween(curve: AppMotion.curve))
          .drive(Tween<Offset>(begin: const Offset(0, -.15), end: Offset.zero)),
      child: ExcludeFocus(
        excluding: !_controller.isExpanded,
        child: IgnorePointer(
          ignoring: !_controller.isExpanded,
          child: ExcludeSemantics(
            excluding: !_controller.isExpanded,
            child: widget.builder(context),
          ),
        ),
      ),
    ),
  );
}
