import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  english('en', 'English', '🇬🇧'),
  tamil('ta', 'தமிழ் (Tamil)', '🇮🇳');

  final String code;
  final String label;
  final String flag;
  const AppLanguage(this.code, this.label, this.flag);
}

class LanguageController extends Notifier<AppLanguage> {
  static const _keyLang = 'app_language';

  @override
  AppLanguage build() {
    _loadFromPrefs();
    return AppLanguage.english;
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final code = prefs.getString(_keyLang);
      if (code == 'ta') {
        state = AppLanguage.tamil;
      } else {
        state = AppLanguage.english;
      }
    } catch (_) {}
  }

  Future<void> setLanguage(AppLanguage lang) async {
    state = lang;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLang, lang.code);
    } catch (_) {}
  }

  void toggleLanguage() {
    if (state == AppLanguage.english) {
      setLanguage(AppLanguage.tamil);
    } else {
      setLanguage(AppLanguage.english);
    }
  }
}

final languageControllerProvider = NotifierProvider<LanguageController, AppLanguage>(() {
  return LanguageController();
});
