import 'package:flutter/material.dart';

import '../../core/theme/app_motion.dart';

/// A soft pill toggle with state marks in the track and a sliding white thumb.
class CrockSwitch extends StatefulWidget {
  const CrockSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;
  @override
  State<CrockSwitch> createState() => _CrockSwitchState();
}

class _CrockSwitchState extends State<CrockSwitch> {
  bool _focused = false;
  void _toggle() => widget.onChanged?.call(!widget.value);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = widget.onChanged != null;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final track = widget.value
        ? Color.lerp(
            colors.surfaceContainerHighest,
            colors.primary,
            dark ? .22 : .1,
          )!
        : colors.surfaceContainerHighest;
    return Semantics(
      label: widget.semanticLabel,
      toggled: widget.value,
      enabled: enabled,
      onTap: enabled ? _toggle : null,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          enabled: enabled,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          mouseCursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _toggle();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? _toggle : null,
            child: SizedBox(
              width: 60,
              height: 44,
              child: Center(
                child: Opacity(
                  opacity: enabled ? 1 : .45,
                  child: AnimatedContainer(
                    duration: duration,
                    curve: AppMotion.curve,
                    width: 60,
                    height: 32,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.lerp(track, colors.shadow, dark ? .12 : .06)!,
                          track,
                        ],
                      ),
                      border: Border.all(
                        width: 1,
                        color: _focused
                            ? colors.primary
                            : colors.outlineVariant,
                      ),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: Align(
                            alignment: widget.value
                                ? AlignmentDirectional.centerStart
                                : AlignmentDirectional.centerEnd,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: Icon(
                                widget.value
                                    ? Icons.check_rounded
                                    : Icons.close_rounded,
                                size: 20,
                                color: widget.value
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                        AnimatedAlign(
                          duration: duration,
                          curve: AppMotion.curve,
                          alignment: widget.value
                              ? AlignmentDirectional.centerEnd
                              : AlignmentDirectional.centerStart,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Colors.white, Color(0xFFF0F3F7)],
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: .85),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.shadow.withValues(
                                    alpha: dark ? .3 : .18,
                                  ),
                                  blurRadius: 5,
                                  offset: const Offset(1, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CrockSwitchListTile extends StatelessWidget {
  const CrockSwitchListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.contentPadding,
  });
  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: ListTile(
      title: title,
      subtitle: subtitle,
      contentPadding: contentPadding,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: CrockSwitch(value: value, onChanged: onChanged),
    ),
  );
}
