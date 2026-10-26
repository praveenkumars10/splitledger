import 'package:flutter_test/flutter_test.dart';
import 'package:split_ledger/features/recurring/models/recurring_expense_model.dart';

void main() {
  group('RecurringExpenseModel Unit Tests', () {
    test('Calculates days until due accurately', () {
      final now = DateTime(2026, 10, 10);
      final itemDue15th = RecurringExpenseModel(
        id: 'rec_1',
        householdId: 'h_1',
        title: 'WiFi Bill',
        amount: 999.0,
        category: 'bills',
        dueDay: 15,
        paidByUid: 'user_1',
        paidByName: 'Praveen',
        createdAt: now,
      );

      expect(itemDue15th.daysUntilDue(now), 5);
      expect(itemDue15th.isDueSoon(now), isFalse); // threshold 3
      expect(itemDue15th.isDueToday(now), isFalse);

      final itemDue12th = itemDue15th.copyWith(dueDay: 12);
      expect(itemDue12th.daysUntilDue(now), 2);
      expect(itemDue12th.isDueSoon(now), isTrue);

      final itemDueToday = itemDue15th.copyWith(dueDay: 10);
      expect(itemDueToday.daysUntilDue(now), 0);
      expect(itemDueToday.isDueToday(now), isTrue);
      expect(itemDueToday.isDueSoon(now), isTrue);
    });

    test('Rolls over to next month when dueDay has already passed this month', () {
      final now = DateTime(2026, 10, 20);
      final itemDue5th = RecurringExpenseModel(
        id: 'rec_2',
        householdId: 'h_1',
        title: 'House Rent',
        amount: 15000.0,
        category: 'rent',
        dueDay: 5,
        paidByUid: 'user_1',
        paidByName: 'Praveen',
        createdAt: now,
      );

      // Next due is Nov 5th: 11 days left in Oct (20 to 31) + 5 days in Nov = 16 days
      expect(itemDue5th.daysUntilDue(now), 16);
      expect(itemDue5th.isDueSoon(now), isFalse);
    });

    test('Cycle logging check', () {
      final item = RecurringExpenseModel(
        id: 'rec_3',
        householdId: 'h_1',
        title: 'Netflix',
        amount: 649.0,
        category: 'entertainment',
        dueDay: 1,
        paidByUid: 'user_1',
        paidByName: 'Praveen',
        lastLoggedCycle: '2026-10',
        createdAt: DateTime(2026, 1, 1),
      );

      expect(item.isLoggedForCycle('2026-10'), isTrue);
      expect(item.isLoggedForCycle('2026-11'), isFalse);
    });

    test('Serialization and deserialization', () {
      final now = DateTime(2026, 10, 26, 12, 0, 0);
      final original = RecurringExpenseModel(
        id: 'rec_test',
        householdId: 'h_123',
        title: 'Car EMI',
        amount: 8500.0,
        category: 'bills',
        dueDay: 7,
        paidByUid: 'uid_1',
        paidByName: 'Praveen',
        notes: 'HDFC Bank Auto-Debit',
        isActive: true,
        lastLoggedCycle: '2026-10',
        createdAt: now,
      );

      final map = original.toMap();
      final reconstructed = RecurringExpenseModel.fromMap(map, docId: 'rec_test');

      expect(reconstructed.id, original.id);
      expect(reconstructed.householdId, original.householdId);
      expect(reconstructed.title, original.title);
      expect(reconstructed.amount, original.amount);
      expect(reconstructed.category, original.category);
      expect(reconstructed.dueDay, original.dueDay);
      expect(reconstructed.paidByUid, original.paidByUid);
      expect(reconstructed.paidByName, original.paidByName);
      expect(reconstructed.notes, original.notes);
      expect(reconstructed.isActive, isTrue);
      expect(reconstructed.lastLoggedCycle, '2026-10');
    });
  });
}
