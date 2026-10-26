import 'package:flutter_test/flutter_test.dart';
import 'package:split_ledger/models/transaction_model.dart';
import 'package:split_ledger/core/localization/app_strings.dart';
import 'package:split_ledger/core/localization/language_controller.dart';

void main() {
  group('Receipt Attachment & Serialization Tests', () {
    final now = DateTime(2026, 10, 26, 12, 0);

    test('TransactionModel stores, serializes, and deserializes receiptUrl correctly', () {
      final tx = TransactionModel(
        id: 'tx_with_receipt_1',
        amount: 850.50,
        category: 'grocery',
        paidByUid: 'user_1',
        paidByName: 'Praveen',
        note: 'Supermarket weekly grocery',
        receiptUrl: '/storage/emulated/0/DCIM/receipt_oct_26.jpg',
        date: now,
        type: TransactionType.paid,
        createdAt: now,
      );

      expect(tx.receiptUrl, equals('/storage/emulated/0/DCIM/receipt_oct_26.jpg'));

      final map = tx.toMap();
      expect(map['receiptUrl'], equals('/storage/emulated/0/DCIM/receipt_oct_26.jpg'));

      final restored = TransactionModel.fromMap(map, 'tx_with_receipt_1');
      expect(restored.id, equals('tx_with_receipt_1'));
      expect(restored.receiptUrl, equals('/storage/emulated/0/DCIM/receipt_oct_26.jpg'));
      expect(restored.amount, equals(850.50));
      expect(restored.category, equals('grocery'));
    });

    test('TransactionModel without receiptUrl defaults to null safely', () {
      final tx = TransactionModel(
        id: 'tx_no_receipt',
        amount: 120.0,
        category: 'tea',
        paidByUid: 'user_1',
        paidByName: 'Praveen',
        date: now,
        type: TransactionType.paid,
        createdAt: now,
      );

      expect(tx.receiptUrl, isNull);
      final map = tx.toMap();
      expect(map['receiptUrl'], isNull);

      final restored = TransactionModel.fromMap(map, 'tx_no_receipt');
      expect(restored.receiptUrl, isNull);
    });

    test('TransactionModel.copyWith updates receiptUrl correctly', () {
      final tx = TransactionModel(
        id: 'tx_copy_test',
        amount: 250.0,
        category: 'fuel',
        paidByUid: 'user_1',
        paidByName: 'Praveen',
        receiptUrl: null,
        date: now,
        type: TransactionType.paid,
        createdAt: now,
      );

      final updated = tx.copyWith(receiptUrl: '/photos/petrol_pump_slip.png');
      expect(updated.receiptUrl, equals('/photos/petrol_pump_slip.png'));
      expect(updated.amount, equals(250.0));
      expect(updated.id, equals('tx_copy_test'));
    });

    test('Receipt localization keys exist for both English and Tamil', () {
      final receiptKeys = [
        'attach_receipt',
        'view_receipt',
        'remove_receipt',
        'take_photo',
        'choose_gallery',
        'receipt_attached',
      ];

      for (final key in receiptKeys) {
        final enVal = AppStrings.tr(AppLanguage.english, key);
        final taVal = AppStrings.tr(AppLanguage.tamil, key);

        expect(enVal, isNotEmpty, reason: 'Key $key should have English translation');
        expect(taVal, isNotEmpty, reason: 'Key $key should have Tamil translation');
        expect(enVal, isNot(equals(key)), reason: 'Key $key should not return untranslated key');
        expect(taVal, isNot(equals(key)), reason: 'Key $key should not return untranslated key in Tamil');
      }
    });
  });
}
