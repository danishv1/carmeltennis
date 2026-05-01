import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  static const _prefsKey = 'booking-theme';

  ThemeMode _mode = ThemeMode.light;
  static final ThemeController instance = ThemeController._internal();
  ThemeController._internal();

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == 'dark') {
      _mode = ThemeMode.dark;
      notifyListeners();
    } else if (raw == 'light') {
      _mode = ThemeMode.light;
      notifyListeners();
    }
  }

  Future<void> setDark(bool isDark) async {
    final newMode = isDark ? ThemeMode.dark : ThemeMode.light;
    if (newMode != _mode) {
      _mode = newMode;
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, isDark ? 'dark' : 'light');
    }
  }

  Future<void> toggle() => setDark(!isDark);
}
