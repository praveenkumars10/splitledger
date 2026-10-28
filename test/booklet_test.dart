import 'package:flutter_test/flutter_test.dart';
import 'package:split_ledger/models/booklet_model.dart';
import 'package:split_ledger/models/transaction_model.dart';

void main() {
  group('BookletModel Unit Tests', () {
    test('BookletModel serialization and deserialization preserves all fields', () {
      final now = DateTime(2026, 10, 28, 15, 30);
      final booklet = BookletModel(
        id: 'booklet_101',
        name: 'Goa Trip 2026',
        startDate: now,
        endDate: now.add(const Duration(days: 5)),
        isClosed: true,
        openingBalance: 5000.0,
        createdByUid: 'uid_user1',
        createdByName: 'Praveen',
        createdAt: now,
        note: 'All food and travel expenses for Goa',
      );

      final json = booklet.toJson();
      final fromJson = BookletModel.fromJson(json);

      expect(fromJson.id, 'booklet_101');
      expect(fromJson.name, 'Goa Trip 2026');
      expect(fromJson.startDate, now);
      expect(fromJson.endDate, now.add(const Duration(days: 5)));
      expect(fromJson.isClosed, isTrue);
      expect(fromJson.openingBalance, 5000.0);
      expect(fromJson.createdByUid, 'uid_user1');
      expect(fromJson.createdByName, 'Praveen');
      expect(fromJson.note, 'All food and travel expenses for Goa');
    });

    test('BookletModel.copyWith updates fields correctly', () {
      final booklet = BookletModel(
        id: 'booklet_1',
        name: 'Home Cashbook',
        startDate: DateTime(2026, 10, 1),
        createdByUid: 'uid_1',
        createdByName: 'User',
        createdAt: DateTime(2026, 10, 1),
      );

      final closed = booklet.copyWith(
        isClosed: true,
        endDate: DateTime(2026, 10, 31),
        name: 'Home Cashbook - Closed',
      );

      expect(closed.id, 'booklet_1');
      expect(closed.name, 'Home Cashbook - Closed');
      expect(closed.isClosed, isTrue);
      expect(closed.endDate, DateTime(2026, 10, 31));
    });
  });

  group('TransactionModel Booklet Integration Tests', () {
    test('TransactionModel stores, serializes, and deserializes bookletId', () {
      final tx = TransactionModel(
        id: 'tx_123',
        amount: 850.0,
        category: 'food',
        paidByUid: 'user_a',
        paidByName: 'Alice',
        date: DateTime(2026, 10, 28),
        createdAt: DateTime(2026, 10, 28),
        bookletId: 'booklet_goa',
      );

      final json = tx.toJson();
      expect(json['bookletId'], 'booklet_goa');

      final reconstructed = TransactionModel.fromJson(json);
      expect(reconstructed.bookletId, 'booklet_goa');

      final copy = tx.copyWith(bookletId: 'booklet_home');
      expect(copy.bookletId, 'booklet_home');
    });

    test('Booklet transaction filtering isolates expenses properly', () {
      final txGoa1 = TransactionModel(
        id: '1',
        amount: 1200.0,
        category: 'food',
        paidByUid: 'u1',
        paidByName: 'User 1',
        date: DateTime(2026, 10, 28),
        createdAt: DateTime(2026, 10, 28),
        bookletId: 'booklet_goa',
      );

      final txGoa2 = TransactionModel(
        id: '2',
        amount: 3500.0,
        category: 'travel',
        paidByUid: 'u2',
        paidByName: 'User 2',
        date: DateTime(2026, 10, 29),
        createdAt: DateTime(2026, 10, 29),
        bookletId: 'booklet_goa',
      );

      final txHome = TransactionModel(
        id: '3',
        amount: 450.0,
        category: 'groceries',
        paidByUid: 'u1',
        paidByName: 'User 1',
        date: DateTime(2026, 10, 28),
        createdAt: DateTime(2026, 10, 28),
        bookletId: 'booklet_home',
      );

      final txUntagged = TransactionModel(
        id: '4',
        amount: 200.0,
        category: 'snacks',
        paidByUid: 'u1',
        paidByName: 'User 1',
        date: DateTime(2026, 10, 27),
        createdAt: DateTime(2026, 10, 27),
        bookletId: null, // Legacy transaction
      );

      final allTransactions = [txGoa1, txGoa2, txHome, txUntagged];

      // Filter for Goa booklet
      final goaExpenses = allTransactions.where((t) => t.bookletId == 'booklet_goa').toList();
      expect(goaExpenses.length, 2);
      expect(goaExpenses.fold(0.0, (s, t) => s + t.amount), 4700.0);

      // Filter for Home booklet
      final homeExpenses = allTransactions.where((t) => t.bookletId == 'booklet_home').toList();
      expect(homeExpenses.length, 1);
      expect(homeExpenses.first.amount, 450.0);

      // Default cashbook accommodates untagged legacy items
      final defaultCashbookExpenses = allTransactions
          .where((t) => t.bookletId == 'default' || t.bookletId == null)
          .toList();
      expect(defaultCashbookExpenses.length, 1);
      expect(defaultCashbookExpenses.first.amount, 200.0);
    });
  });
}

