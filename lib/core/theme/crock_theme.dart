import 'package:flutter/material.dart';

abstract final class CrockTheme {
  static const blue = Color(0xFF087CFA);
  static const cyan = Color(0xFF19C8DF);
  static const ink = Color(0xFF172B45);
  static const muted = Color(0xFF738398);
  static const line = Color(0xFFE9EEF5);
  static const background = Color(0xFFF5F8FC);

  static Color inkOf(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;
  static Color mutedOf(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;
  static Color lineOf(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;
  static Color surfaceOf(BuildContext context) =>
      Theme.of(context).colorScheme.surface;
  static Color subtleSurfaceOf(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerLow;

  static ThemeData get light => _build(dark: false);
  static ThemeData get dark => _build(dark: true);

  static ThemeData _build({required bool dark}) {
    const darkInk = Color(0xFFE7EEF8);
    const darkMuted = Color(0xFFA7B5C8);
    const darkLine = Color(0xFF2A3B50);
    const darkSurface = Color(0xFF172536);
    const darkBackground = Color(0xFF0D1826);
    const darkSubtle = Color(0xFF1E3044);
    final foreground = dark ? darkInk : ink;
    final mutedForeground = dark ? darkMuted : muted;
    final lineColor = dark ? darkLine : line;
    final surfaceColor = dark ? darkSurface : Colors.white;
    final backgroundColor = dark ? darkBackground : background;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: blue,
          brightness: dark ? Brightness.dark : Brightness.light,
        ).copyWith(
          primary: blue,
          onPrimary: Colors.white,
          primaryContainer: dark
              ? const Color(0xFF153A63)
              : const Color(0xFFEAF3FF),
          onPrimaryContainer: dark
              ? const Color(0xFFD2E5FF)
              : const Color(0xFF075BB9),
          secondary: cyan,
          surface: surfaceColor,
          onSurface: foreground,
          onSurfaceVariant: mutedForeground,
          outlineVariant: lineColor,
        );
    final base = ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
    );
    return base.copyWith(
      scaffoldBackgroundColor: backgroundColor,
      textTheme: base.textTheme
          .apply(bodyColor: foreground, displayColor: foreground)
          .copyWith(
            titleLarge: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              letterSpacing: -.5,
            ).copyWith(color: foreground),
            titleMedium: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ).copyWith(color: foreground),
            bodyMedium: TextStyle(
              color: foreground,
              fontSize: 14,
              height: 1.45,
            ),
            bodySmall: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: mutedForeground,
            ),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: foreground,
        titleTextStyle: TextStyle(
          fontSize: 23,
          fontWeight: FontWeight.w700,
          color: foreground,
          letterSpacing: -.5,
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? darkSubtle : const Color(0xFFF1F5FA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        hintStyle: TextStyle(color: mutedForeground, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: blue, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: lineColor),
        ),
      ),
      dividerTheme: DividerThemeData(color: lineColor, thickness: 1, space: 1),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: blue,
        inactiveTrackColor: dark ? darkLine : const Color(0xFFE5ECF5),
        thumbColor: blue,
        overlayColor: blue.withValues(alpha: .08),
        trackHeight: 5,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? Colors.white : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? blue
              : dark
              ? darkLine
              : const Color(0xFFEBF0F6),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: dark ? darkLine : const Color(0xFFD4DDE8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
