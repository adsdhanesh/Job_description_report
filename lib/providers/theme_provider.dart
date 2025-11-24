// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';

/// Simple ThemeProvider that toggles between light and dark themes.
/// Persistence is intentionally omitted to keep this dependency-free.
/// If you want persistence, uncomment SharedPreferences parts and add the package.
class ThemeProvider extends ChangeNotifier {
  bool _isDark = true; // default to dark to match your dashboard palette

  bool get isDark => _isDark;

  ThemeMode get mode => _isDark ? ThemeMode.dark : ThemeMode.light;

  void toggle() {
    _isDark = !_isDark;
    notifyListeners();
  }

  void setDark(bool value) {
    _isDark = value;
    notifyListeners();
  }

  // Optional: persistence hooks (requires shared_preferences).
  // Future<void> load() async { ... }
  // Future<void> save() async { ... }
}
