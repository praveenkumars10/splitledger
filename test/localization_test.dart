import 'package:flutter_test/flutter_test.dart';
import 'package:split_ledger/core/localization/app_strings.dart';
import 'package:split_ledger/core/localization/language_controller.dart';

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
  });
}
