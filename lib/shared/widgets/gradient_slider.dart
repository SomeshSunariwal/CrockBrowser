import 'package:flutter/material.dart';

/// A continuous theme-colored gradient ending at a clean white thumb.
class ThemeGradientSliderTrack extends RoundedRectSliderTrackShape {
  const ThemeGradientSliderTrack({required this.start, required this.end});
  final Color start, end;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    final track = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );
    if (track.isEmpty) return;
    final pill = RRect.fromRectAndRadius(
      track,
      Radius.circular(track.height / 2),
    );
    final canvas = context.canvas;
    final disabled = sliderTheme.disabledActiveTrackColor ?? Colors.grey;
    final enabled = enableAnimation.value;
    final inactive = Color.lerp(
      sliderTheme.disabledInactiveTrackColor,
      sliderTheme.inactiveTrackColor,
      enabled,
    )!;
    canvas.drawRRect(pill, Paint()..color = inactive);
    final rtl = textDirection == TextDirection.rtl;
    final x = thumbCenter.dx.clamp(track.left, track.right);
    final active = Rect.fromLTRB(
      rtl ? x : track.left,
      track.top,
      rtl ? track.right : x,
      track.bottom,
    );
    canvas.save();
    canvas.clipRect(active);
    canvas.drawRRect(
      pill,
      Paint()
        ..shader = LinearGradient(
          begin: rtl ? Alignment.centerRight : Alignment.centerLeft,
          end: rtl ? Alignment.centerLeft : Alignment.centerRight,
          colors: [
            Color.lerp(disabled, start, enabled)!,
            Color.lerp(disabled, end, enabled)!,
          ],
        ).createShader(track),
    );
    canvas.restore();
  }
}

class ThemeSliderThumb extends SliderComponentShape {
  const ThemeSliderThumb();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(20, 20);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(
      center,
      10,
      Paint()..color = sliderTheme.thumbColor ?? Colors.white,
    );
    canvas.drawCircle(
      center,
      10,
      Paint()
        ..color = (sliderTheme.activeTrackColor ?? Colors.blue).withValues(
          alpha: .25,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }
}
