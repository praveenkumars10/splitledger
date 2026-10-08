import 'package:flutter_test/flutter_test.dart';
import 'package:split_ledger/core/categories.dart';
import 'package:split_ledger/core/localization/app_strings.dart';
import 'package:split_ledger/core/localization/language_controller.dart';
import 'package:split_ledger/core/theme/theme_controller.dart';

void main() {
  group('App Localization & Translation Tests', () {
    test('English and Tamil dictionaries provide valid translations for all key categories', () {
      final testKeys = [
        'app_title',
        'home_tab',
        'split_tab',
        'history_tab',
        'reports_tab',
        'settings_tab',
        'wallet',
        'wallet_amount',
        'wallet_balance',
        'total_received',
        'total_paid',
        'your_balance',
        'cash_in',
        'cash_out',
        'you_paid',
        'you_received',
        'quick_expense',
        'quick_save_expense',
        'settle_up',
        'settlements',
        'no_due',
        'pay_upi',
        'remind_whatsapp',
        'mark_paid',
        'daily_spend_target',
        'category_breakdown',
        'all_time',
        'monthly',
        'search_hint',
        'filter_options',
        'export_csv',
        'export_pdf',
        'food',
        'fuel',
        'tea',
        'grocery',
        'rent',
        'bills',
        'entertainment',
        'shopping',
        'other',
      ];

      for (final key in testKeys) {
        final enText = AppStrings.tr(AppLanguage.english, key);
        final taText = AppStrings.tr(AppLanguage.tamil, key);

        expect(enText, isNotEmpty, reason: 'English missing key: $key');
        expect(taText, isNotEmpty, reason: 'Tamil missing key: $key');
        expect(enText, isNot(equals(key)), reason: 'English returned untranslated key: $key');
        expect(taText, isNot(equals(key)), reason: 'Tamil returned untranslated key: $key');
      }
    });

    test('AppLanguage flag and label are valid', () {
      for (final lang in AppLanguage.values) {
        expect(lang.code, isNotEmpty);
        expect(lang.label, isNotEmpty);
        expect(lang.flag, isNotEmpty);
      }
    });

    test('All AppCategories have valid icons, colors, and bilingual translations', () {
      for (final cat in appCategories) {
        expect(cat.id, isNotEmpty);
        expect(cat.emoji, isNotEmpty);
        expect(cat.color, isNotNull);
        final enName = cat.getLocalizedName(AppLanguage.english);
        final taName = cat.getLocalizedName(AppLanguage.tamil);
        expect(enName, isNotEmpty);
        expect(taName, isNotEmpty);
        expect(enName, isNot(equals(cat.id)));
        expect(taName, isNot(equals(cat.id)));
      }
    });

    test('All AppThemeColors have valid colors, English and Tamil labels', () {
      expect(AppThemeColor.values.length, 7);
      for (final themeColor in AppThemeColor.values) {
        expect(themeColor.color, isNotNull);
        expect(themeColor.label, isNotEmpty);
        expect(themeColor.tamilLabel, isNotEmpty);
        expect(themeColor.getLocalizedLabel(AppLanguage.english), equals(themeColor.label));
        expect(themeColor.getLocalizedLabel(AppLanguage.tamil), equals(themeColor.tamilLabel));
      }
    });
  });
}
