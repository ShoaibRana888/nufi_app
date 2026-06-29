// lib/config/theme.dart
//
// Central light + dark themes for the app. Screens should prefer
// `Theme.of(context)` / `context.colorScheme` over hardcoded Colors.* so they
// adapt to dark mode automatically.
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  /// Brand primary (matches the historical `Colors.blue`).
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color primaryBlueDark = Color(0xFF64B5F6);

  // Light surfaces
  static const Color _lightScaffold = Color(0xFFF5F6F8);
  static const Color _lightSurface = Colors.white;

  // Dark surfaces (Material dark guidance)
  static const Color _darkScaffold = Color(0xFF121212);
  static const Color _darkSurface = Color(0xFF1E1E1E);
  static const Color _darkSurfaceAlt = Color(0xFF262626);

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.light,
    ).copyWith(
      primary: primaryBlue,
      surface: _lightSurface,
    );
    return _base(scheme, _lightScaffold, primaryBlue);
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryBlue,
      brightness: Brightness.dark,
    ).copyWith(
      primary: primaryBlueDark,
      surface: _darkSurface,
      surfaceContainerHighest: _darkSurfaceAlt,
    );
    return _base(scheme, _darkScaffold, _darkSurface);
  }

  static ThemeData _base(
    ColorScheme scheme,
    Color scaffold,
    Color appBarColor,
  ) {
    final isDark = scheme.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      primaryColor: scheme.primary,
      scaffoldBackgroundColor: scaffold,
      canvasColor: scheme.surface,
      dividerColor: isDark ? Colors.white12 : Colors.black12,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? _darkSurface : AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: isDark ? 1 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: isDark ? Colors.grey.shade500 : Colors.grey,
        type: BottomNavigationBarType.fixed,
      ),
      iconTheme: IconThemeData(color: scheme.primary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? _darkSurfaceAlt : Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: BorderSide(color: scheme.primary),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? scheme.primary : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary.withValues(alpha: 0.5)
              : null,
        ),
      ),
    );
  }
}

/// Convenience accessors so screens can write `context.colorScheme.surface`
/// and a few semantic colors without long `Theme.of(context)` chains.
extension ThemeContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Card / elevated surface color.
  Color get surfaceColor => Theme.of(this).colorScheme.surface;

  /// Scaffold background.
  Color get scaffoldColor => Theme.of(this).scaffoldBackgroundColor;

  /// Primary text/icon color on a surface.
  Color get onSurfaceColor => Theme.of(this).colorScheme.onSurface;

  /// Muted/secondary text color.
  Color get mutedColor =>
      Theme.of(this).colorScheme.onSurface.withValues(alpha: 0.6);
}
