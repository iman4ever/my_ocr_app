import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const _prefKey = 'selectedLanguage';
  static const _defaultLanguage = 'en';
  static const _supportedLanguages = ['en', 'fr', 'ar'];

  late String _language;

  LanguageProvider({String initialLanguage = _defaultLanguage})
      : _language = initialLanguage {
    _loadFromPrefs();
  }

  String get language => _language;

  String get displayName {
    switch (_language) {
      case 'en':
        return 'English';
      case 'fr':
        return 'French';
      case 'ar':
        return 'Arabic';
      default:
        return 'English';
    }
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved != null && _supportedLanguages.contains(saved)) {
      _language = saved;
      notifyListeners();
    }
  }

  Future<void> setLanguage(String lang) async {
    if (!_supportedLanguages.contains(lang)) return;

    _language = lang;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, lang);
  }
}
