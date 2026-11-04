import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_ledger/models/deleted_audit_item_model.dart';
import 'package:split_ledger/models/transaction_model.dart';
import 'package:split_ledger/models/booklet_model.dart';
import 'package:split_ledger/features/history/deleted_history_repository.dart';

void main() {
  group('DeletedAuditItemModel Tests', () {
    test('Builds audit item correctly from deleted transaction with booklet info', () {
      final tx = TransactionModel(
        id: 'tx_123',
        amount: 850.50,
        category: 'Food & Dining',
        paidByUid: 'user_a',
        paidByName: 'Karthik',
        note: 'Team Lunch',
        date: DateTime(2026, 11, 1, 13, 0),
        createdAt: DateTime(2026, 11, 1, 13, 0),
        bookletId: 'booklet_goa',
        splitPercentages: {'user_a': 50.0, 'user_b': 50.0},
      );

      final auditItem = DeletedAuditItemModel.fromTransaction(
        id: 'audit_001',
        transaction: tx,
        deletedByUid: 'user_b',
        deletedByName: 'Praveen',
        bookletName: 'Goa Trip 2026',
      );

      expect(auditItem.id, 'audit_001');
      expect(auditItem.type, DeletedItemType.transaction);
      expect(auditItem.deletedByUid, 'user_b');
      expect(auditItem.deletedByName, 'Praveen');
      expect(auditItem.bookletId, 'booklet_goa');
      expect(auditItem.bookletName, 'Goa Trip 2026');
      expect(auditItem.originalTransactionId, 'tx_123');
      expect(auditItem.amount, 850.50);
      expect(auditItem.category, 'Food & Dining');
      expect(auditItem.note, 'Team Lunch');
      expect(auditItem.paidByUid, 'user_a');
      expect(auditItem.paidByName, 'Karthik');
      expect(auditItem.splitPercentages?['user_a'], 50.0);
    });

    test('Builds audit item correctly from deleted booklet', () {
      final booklet = BookletModel(
        id: 'booklet_goa',
        name: 'Goa Trip 2026',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 15),
        openingBalance: 5000.0,
        createdByUid: 'user_a',
        createdByName: 'Karthik',
        createdAt: DateTime(2026, 10, 1),
      );

      final auditItem = DeletedAuditItemModel.fromBooklet(
        id: 'audit_booklet_001',
        booklet: booklet,
        deletedByUid: 'user_b',
        deletedByName: 'Praveen',
        transactionCount: 14,
        totalAmount: 18450.0,
      );

      expect(auditItem.id, 'audit_booklet_001');
      expect(auditItem.type, DeletedItemType.booklet);
      expect(auditItem.deletedByUid, 'user_b');
      expect(auditItem.deletedByName, 'Praveen');
      expect(auditItem.bookletId, 'booklet_goa');
      expect(auditItem.bookletName, 'Goa Trip 2026');
      expect(auditItem.originalBookletId, 'booklet_goa');
      expect(auditItem.bookletOpeningBalance, 5000.0);
      expect(auditItem.bookletCreatedByName, 'Karthik');
      expect(auditItem.transactionCount, 14);
      expect(auditItem.totalAmount, 18450.0);
    });

    test('toMap and fromMap preserves all fields and types', () {
      final deleteTime = DateTime(2026, 11, 4, 15, 30);
      final item = DeletedAuditItemModel(
        id: 'audit_999',
        type: DeletedItemType.transaction,
        deletedByUid: 'user_x',
        deletedByName: 'Alice',
        deletedAt: deleteTime,
        bookletId: 'b_12',
        bookletName: 'November Budget',
        originalTransactionId: 'tx_old',
        amount: 1200.0,
        category: 'Groceries',
        note: 'Supermarket weekly buy',
        paidByUid: 'user_y',
        paidByName: 'Bob',
        transactionDate: DateTime(2026, 11, 2),
        transactionType: 'paid',
        splitPercentages: {'user_x': 60.0, 'user_y': 40.0},
      );

      final map = item.toMap();
      expect(map['type'], 'transaction');
      expect(map['deletedByName'], 'Alice');
      expect(map['bookletName'], 'November Budget');
      expect(map['amount'], 1200.0);
      expect(map['deletedAt'], isA<Timestamp>());

      final reconstructed = DeletedAuditItemModel.fromMap(map, 'audit_999');
      expect(reconstructed.id, 'audit_999');
      expect(reconstructed.type, DeletedItemType.transaction);
      expect(reconstructed.deletedByUid, 'user_x');
      expect(reconstructed.deletedByName, 'Alice');
      expect(reconstructed.deletedAt.year, 2026);
      expect(reconstructed.bookletId, 'b_12');
      expect(reconstructed.bookletName, 'November Budget');
      expect(reconstructed.originalTransactionId, 'tx_old');
      expect(reconstructed.amount, 1200.0);
      expect(reconstructed.category, 'Groceries');
      expect(reconstructed.splitPercentages?['user_x'], 60.0);
    });

    test('Preserves default booklet name if transaction has no bookletId', () {
      final tx = TransactionModel(
        id: 'tx_legacy',
        amount: 200.0,
        category: 'Travel',
        paidByUid: 'uid_1',
        paidByName: 'User 1',
        date: DateTime(2026, 10, 10),
        createdAt: DateTime(2026, 10, 10),
      );

      final audit = DeletedAuditItemModel.fromTransaction(
        id: 'audit_def',
        transaction: tx,
        deletedByUid: 'uid_2',
        deletedByName: 'User 2',
      );

      expect(audit.bookletName, 'Main Cashbook');
    });

    test('3-Month (90-day) Retention Cutoff Logic', () {
      final now = DateTime.now();
      const retention = DeletedHistoryRepository.retentionPeriod;
      expect(retention.inDays, 90);

      final cutoff = now.subtract(retention);

      // An entry deleted 45 days ago should be KEPT
      final recentEntry = now.subtract(const Duration(days: 45));
      expect(recentEntry.isAfter(cutoff), isTrue);

      // An entry deleted 89 days ago should be KEPT
      final nearExpiryEntry = now.subtract(const Duration(days: 89));
      expect(nearExpiryEntry.isAfter(cutoff), isTrue);

      // An entry deleted 91 days ago (older than 3 months) should be EXPIRED
      final expiredEntry = now.subtract(const Duration(days: 91));
      expect(expiredEntry.isAfter(cutoff), isFalse);

      // An entry deleted 120 days ago should be EXPIRED
      final oldEntry = now.subtract(const Duration(days: 120));
      expect(oldEntry.isAfter(cutoff), isFalse);
    });
  });
}

