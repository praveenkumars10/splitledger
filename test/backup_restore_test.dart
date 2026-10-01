import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_ledger/core/services/backup_restore_service.dart';
import 'package:split_ledger/models/transaction_model.dart';

void main() {
  group('TransactionModel JSON Serialization & Backup Validation', () {
    test('TransactionModel toJson and fromJson preserves all fields', () {
      final tx = TransactionModel(
        id: 'tx_123',
        amount: 250.75,
        category: 'food',
        paidByUid: 'user_1',
        paidByName: 'Praveen',
        note: 'Dinner with friends',
        date: DateTime(2026, 10, 1, 14, 30),
        type: TransactionType.paid,
        createdAt: DateTime(2026, 10, 1, 14, 30),
        recurrence: RecurrenceInterval.monthly,
      );

      final jsonMap = tx.toJson();
      expect(jsonMap['id'], 'tx_123');
      expect(jsonMap['amount'], 250.75);
      expect(jsonMap['category'], 'food');
      expect(jsonMap['recurrence'], 'monthly');

      final reconstructed = TransactionModel.fromJson(jsonMap);
      expect(reconstructed.id, tx.id);
      expect(reconstructed.amount, tx.amount);
      expect(reconstructed.category, tx.category);
      expect(reconstructed.paidByName, tx.paidByName);
      expect(reconstructed.note, tx.note);
      expect(reconstructed.type, TransactionType.paid);
      expect(reconstructed.recurrence, RecurrenceInterval.monthly);
    });

    test('BackupRestoreService validates correct backup JSON format', () {
      final validJson = jsonEncode({
        'version': 1,
        'appName': 'SplitLedger',
        'exportedAt': DateTime.now().toIso8601String(),
        'householdName': 'Office Group',
        'walletAmount': 3000.0,
        'transactions': [
          {
            'id': '1',
            'amount': 50.0,
            'category': 'tea',
            'paidByUid': 'u1',
            'paidByName': 'User 1',
            'note': 'Evening Tea',
            'date': DateTime.now().toIso8601String(),
            'type': 'paid',
            'createdAt': DateTime.now().toIso8601String(),
          }
        ],
      });

      final validated = BackupRestoreService.validateBackupJson(validJson);
      expect(validated, isNotNull);
      expect(validated!['appName'], 'SplitLedger');
      expect((validated['transactions'] as List).length, 1);
    });

    test('BackupRestoreService rejects malformed or invalid JSON', () {
      expect(BackupRestoreService.validateBackupJson('invalid json string'), isNull);
      expect(BackupRestoreService.validateBackupJson('{"version": 1}'), isNull); // missing transactions key
    });
  });
}
