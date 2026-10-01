import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StorageMode {
  cloud('Cloud Sync (Firebase)', 'Real-time multi-user synchronization with Google Cloud Firebase'),
  local('Device Only (Offline)', 'Private local device storage with full offline JSON backups');

  final String title;
  final String description;
  const StorageMode(this.title, this.description);
}

class AppPreferences {
  final bool isPrivacyMode;
  final StorageMode storageMode;
  final String currencySymbol;
  final String currencyCode;

  const AppPreferences({
    this.isPrivacyMode = false,
    this.storageMode = StorageMode.cloud,
    this.currencySymbol = '₹',
    this.currencyCode = 'en_IN',
  });

  AppPreferences copyWith({
    bool? isPrivacyMode,
    StorageMode? storageMode,
    String? currencySymbol,
    String? currencyCode,
  }) {
    return AppPreferences(
      isPrivacyMode: isPrivacyMode ?? this.isPrivacyMode,
      storageMode: storageMode ?? this.storageMode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }
}

class AppPreferencesController extends Notifier<AppPreferences> {
  static const _keyPrivacy = 'pref_privacy_mode';
  static const _keyStorage = 'pref_storage_mode';
  static const _keyCurrencySymbol = 'pref_currency_symbol';
  static const _keyCurrencyCode = 'pref_currency_code';

  @override
  AppPreferences build() {
    _loadFromPrefs();
    return const AppPreferences();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final privacy = prefs.getBool(_keyPrivacy) ?? false;
      final storageIdx = prefs.getInt(_keyStorage) ?? 0;
      final sym = prefs.getString(_keyCurrencySymbol) ?? '₹';
      final code = prefs.getString(_keyCurrencyCode) ?? 'en_IN';

      state = AppPreferences(
        isPrivacyMode: privacy,
        storageMode: StorageMode.values[storageIdx.clamp(0, StorageMode.values.length - 1)],
        currencySymbol: sym,
        currencyCode: code,
      );
    } catch (_) {}
  }

  Future<void> togglePrivacyMode() async {
    final next = !state.isPrivacyMode;
    state = state.copyWith(isPrivacyMode: next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyPrivacy, next);
    } catch (_) {}
  }

  Future<void> setStorageMode(StorageMode mode) async {
    state = state.copyWith(storageMode: mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyStorage, mode.index);
    } catch (_) {}
  }

  Future<void> setCurrency(String symbol, String localeCode) async {
    state = state.copyWith(currencySymbol: symbol, currencyCode: localeCode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCurrencySymbol, symbol);
      await prefs.setString(_keyCurrencyCode, localeCode);
    } catch (_) {}
  }
}

final appPreferencesProvider = NotifierProvider<AppPreferencesController, AppPreferences>(() {
  return AppPreferencesController();
});
