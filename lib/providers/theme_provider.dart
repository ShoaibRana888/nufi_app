// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app's [ThemeMode] and persists the user's choice.
///
/// Works identically on iOS, Android and web. `ThemeMode.system` follows the
/// OS/browser dark-mode setting.
class ThemeProvider extends ChangeNotifier {
  static const String _prefsKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      _themeMode = _fromString(stored);
      notifyListeners();
    } catch (_) {
      // Keep default (system) on any failure.
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, _toString(mode));
    } catch (_) {
      // Non-fatal: choice still applies for this session.
    }
  }

  /// Maps the value used by the Settings dropdown ('Light'/'Dark'/'System').
  Future<void> setFromLabel(String label) {
    switch (label.toLowerCase()) {
      case 'light':
        return setThemeMode(ThemeMode.light);
      case 'dark':
        return setThemeMode(ThemeMode.dark);
      default:
        return setThemeMode(ThemeMode.system);
    }
  }

  String get label {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  static ThemeMode _fromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _toString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
