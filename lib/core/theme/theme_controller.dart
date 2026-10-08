import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/localization/language_controller.dart';

enum AppThemeColor {
  emerald(Color(0xFF0F766E), 'Emerald Green', 'மரகத பச்சை'),
  deepPurple(Color(0xFF673AB7), 'Deep Purple', 'அடர் ஊதா'),
  oceanBlue(Color(0xFF1976D2), 'Ocean Blue', 'கடல் நீலம்'),
  amberGold(Color(0xFFD97706), 'Amber Gold', 'தங்க நிறம்'),
  royalIndigo(Color(0xFF4338CA), 'Royal Indigo', 'ராயல் இண்டிகோ'),
  rubyCrimson(Color(0xFFE11D48), 'Ruby Crimson', 'ரூபி சிவப்பு'),
  slateCharcoal(Color(0xFF334155), 'Slate Charcoal', 'ஸ்லேட் சாம்பல்');

  final Color color;
  final String label;
  final String tamilLabel;
  const AppThemeColor(this.color, this.label, this.tamilLabel);

  String getLocalizedLabel(AppLanguage language) {
    return language == AppLanguage.tamil ? tamilLabel : label;
  }
}

class ThemeSettings {
  final ThemeMode themeMode;
  final AppThemeColor accentColor;

  const ThemeSettings({
    this.themeMode = ThemeMode.system,
    this.accentColor = AppThemeColor.emerald,
  });

  ThemeSettings copyWith({
    ThemeMode? themeMode,
    AppThemeColor? accentColor,
  }) {
    return ThemeSettings(
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
    );
  }
}

class ThemeController extends Notifier<ThemeSettings> {
  static const _keyMode = 'theme_mode';
  static const _keyColor = 'theme_color';

  @override
  ThemeSettings build() {
    _loadFromPrefs();
    return const ThemeSettings();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeIndex = prefs.getInt(_keyMode);
      final colorIndex = prefs.getInt(_keyColor);

      ThemeMode mode = ThemeMode.system;
      if (modeIndex != null && modeIndex >= 0 && modeIndex < ThemeMode.values.length) {
        mode = ThemeMode.values[modeIndex];
      }

      AppThemeColor color = AppThemeColor.emerald;
      if (colorIndex != null && colorIndex >= 0 && colorIndex < AppThemeColor.values.length) {
        color = AppThemeColor.values[colorIndex];
      }

      state = ThemeSettings(themeMode: mode, accentColor: color);
    } catch (_) {
      // Use defaults if SharedPreferences is unavailable
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyMode, mode.index);
    } catch (_) {}
  }

  Future<void> setAccentColor(AppThemeColor color) async {
    state = state.copyWith(accentColor: color);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyColor, color.index);
    } catch (_) {}
  }
}

final themeControllerProvider = NotifierProvider<ThemeController, ThemeSettings>(() {
  return ThemeController();
});
