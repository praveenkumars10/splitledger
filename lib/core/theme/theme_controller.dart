import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeColor {
  emerald(Color(0xFF0F766E), 'Emerald Green'),
  deepPurple(Color(0xFF673AB7), 'Deep Purple'),
  oceanBlue(Color(0xFF1976D2), 'Ocean Blue'),
  amberGold(Color(0xFFD97706), 'Amber Gold');

  final Color color;
  final String label;
  const AppThemeColor(this.color, this.label);
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
