import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'isDarkMode';

  ThemeMode _themeMode;

  ThemeProvider({ThemeMode initialMode = ThemeMode.light}) : _themeMode = initialMode {
    _loadFromPrefs();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getBool(_prefKey);
    if (val != null) {
      _themeMode = val ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    }
  }

  Future<void> setDarkMode(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, isDark);
  }

  Future<void> toggle() async => setDarkMode(!isDarkMode);
}
