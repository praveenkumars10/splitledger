import 'package:flutter_test/flutter_test.dart';
import 'package:split_ledger/core/date_filters.dart';
import 'package:split_ledger/models/household_model.dart';
import 'package:split_ledger/models/transaction_model.dart';

void main() {
  group('DateCycleRange & Salary/Billing Cycle Calculations', () {
    test('Default day 1 produces standard calendar month', () {
      final ref = DateTime(2026, 10, 15);
      final cycle = getCycleRangeForDate(ref, 1);

      expect(cycle.cycleStartDay, 1);
      expect(cycle.start.year, 2026);
      expect(cycle.start.month, 10);
      expect(cycle.start.day, 1);

      expect(cycle.end.year, 2026);
      expect(cycle.end.month, 10);
      expect(cycle.end.day, 31);
      expect(cycle.label, 'Oct 2026');
    });

    test('Cycle start day 7 when date is after 7th (e.g. Oct 26) runs Oct 7 to Nov 6', () {
      final ref = DateTime(2026, 10, 26);
      final cycle = getCycleRangeForDate(ref, 7);

      expect(cycle.cycleStartDay, 7);
      expect(cycle.start.year, 2026);
      expect(cycle.start.month, 10);
      expect(cycle.start.day, 7);

      expect(cycle.end.year, 2026);
      expect(cycle.end.month, 11);
      expect(cycle.end.day, 6);
      expect(cycle.label, '7 Oct – 6 Nov 2026');
    });

    test('Cycle start day 7 when date is before 7th (e.g. Oct 3) runs Sep 7 to Oct 6', () {
      final ref = DateTime(2026, 10, 3);
      final cycle = getCycleRangeForDate(ref, 7);

      expect(cycle.start.year, 2026);
      expect(cycle.start.month, 9);
      expect(cycle.start.day, 7);

      expect(cycle.end.year, 2026);
      expect(cycle.end.month, 10);
      expect(cycle.end.day, 6);
      expect(cycle.label, '7 Sep – 6 Oct 2026');
    });

    test('Cycle navigation with offset steps accurately across month and year boundaries', () {
      final base = DateTime(2026, 12, 10);
      final decCycle = getCycleRangeForDate(base, 7);
      expect(decCycle.start, DateTime(2026, 12, 7));
      expect(decCycle.end.year, 2027);
      expect(decCycle.end.month, 1);
      expect(decCycle.end.day, 6);

      // Next cycle (+1) -> Jan 7 to Feb 6 2027
      final nextCycle = getCycleRangeWithOffset(base, 7, 1);
      expect(nextCycle.start, DateTime(2027, 1, 7));
      expect(nextCycle.end.year, 2027);
      expect(nextCycle.end.month, 2);
      expect(nextCycle.end.day, 6);

      // Previous cycle (-1) -> Nov 7 to Dec 6 2026
      final prevCycle = getCycleRangeWithOffset(base, 7, -1);
      expect(prevCycle.start, DateTime(2026, 11, 7));
      expect(prevCycle.end.year, 2026);
      expect(prevCycle.end.month, 12);
      expect(prevCycle.end.day, 6);
    });

    test('Handles short months clamping (e.g. Feb 28 with cycle day 31)', () {
      final ref = DateTime(2026, 2, 15);
      final cycle = getCycleRangeForDate(ref, 31);

      // In non-leap year 2026, Feb has 28 days
      expect(cycle.start.year, 2026);
      expect(cycle.start.month, 1);
      expect(cycle.start.day, 31);

      expect(cycle.end.year, 2026);
      expect(cycle.end.month, 2);
      expect(cycle.end.day, 28);
    });

    test('DateCycleRange contains correctly checks boundaries without overlaps', () {
      final cycle = getCycleRangeForDate(DateTime(2026, 10, 15), 7);
      // Range is Oct 7 00:00:00 to Nov 6 23:59:59.999

      expect(cycle.contains(DateTime(2026, 10, 6, 23, 59)), isFalse);
      expect(cycle.contains(DateTime(2026, 10, 7, 0, 0)), isTrue);
      expect(cycle.contains(DateTime(2026, 10, 20)), isTrue);
      expect(cycle.contains(DateTime(2026, 11, 6, 23, 59)), isTrue);
      expect(cycle.contains(DateTime(2026, 11, 7, 0, 0)), isFalse); // Belongs to next cycle
    });

    test('daysRemaining calculates remaining days in active cycle', () {
      final cycle = getCycleRangeForDate(DateTime(2026, 10, 26), 7);
      // Cycle ends on Nov 6
      final today = DateTime(2026, 10, 26);
      // From 26th Oct to 6th Nov inclusive: (31 - 26 + 1) + 6 = 6 + 6 = 12 days
      expect(cycle.daysRemaining(today), 12);
    });
  });

  group('filterTransactions with cycleStartDay', () {
    final txList = [
      TransactionModel(
        id: '1',
        amount: 500,
        category: 'Food',
        paidByUid: 'u1',
        paidByName: 'User 1',
        date: DateTime(2026, 10, 6), // Previous cycle (Sep 7 - Oct 6)
        createdAt: DateTime(2026, 10, 6),
      ),
      TransactionModel(
        id: '2',
        amount: 800,
        category: 'Grocery',
        paidByUid: 'u1',
        paidByName: 'User 1',
        date: DateTime(2026, 10, 7), // Active cycle (Oct 7 - Nov 6)
        createdAt: DateTime(2026, 10, 7),
      ),
      TransactionModel(
        id: '3',
        amount: 1200,
        category: 'Rent',
        paidByUid: 'u2',
        paidByName: 'User 2',
        date: DateTime(2026, 11, 6), // Active cycle (Oct 7 - Nov 6)
        createdAt: DateTime(2026, 11, 6),
      ),
      TransactionModel(
        id: '4',
        amount: 300,
        category: 'Fuel',
        paidByUid: 'u1',
        paidByName: 'User 1',
        date: DateTime(2026, 11, 7), // Next cycle (Nov 7 - Dec 6)
        createdAt: DateTime(2026, 11, 7),
      ),
    ];

    test('Monthly/Cycle filter with cycleStartDay=7 filters correctly', () {
      final filtered = filterTransactions(
        txList,
        timeFilter: 'Cycle',
        userFilter: 'all',
        selectedMonth: DateTime(2026, 10, 26),
        cycleStartDay: 7,
      );

      expect(filtered.length, 2);
      expect(filtered.map((t) => t.id).toList(), ['2', '3']);
    });

    test('Standard calendar month (cycleStartDay=1) filters by calendar month Oct 1-31', () {
      final filtered = filterTransactions(
        txList,
        timeFilter: 'Monthly',
        userFilter: 'all',
        selectedMonth: DateTime(2026, 10, 15),
        cycleStartDay: 1,
      );

      expect(filtered.length, 2);
      expect(filtered.map((t) => t.id).toList(), ['1', '2']);
    });
  });

  group('Household Model cycleStartDay Serialization', () {
    test('serializes and deserializes cycleStartDay correctly', () {
      final household = Household(
        id: 'h123',
        name: 'Family Home',
        members: [HouseholdMember(uid: 'u1', name: 'Alice')],
        createdAt: DateTime(2026, 1, 1),
        inviteCode: 'XYZ123',
        cycleStartDay: 7,
      );

      final map = household.toMap();
      expect(map['cycleStartDay'], 7);

      final reconstructed = Household.fromMap(map, 'h123');
      expect(reconstructed.cycleStartDay, 7);
      expect(reconstructed.name, 'Family Home');
    });

    test('defaults to 1 if cycleStartDay is missing from map', () {
      final legacyMap = {
        'name': 'Legacy Household',
        'members': [],
        'inviteCode': 'LEGACY1',
      };

      final household = Household.fromMap(legacyMap, 'h_legacy');
      expect(household.cycleStartDay, 1);
    });

    test('copyWith updates cycleStartDay', () {
      final household = Household(
        id: 'h1',
        name: 'House',
        members: [],
        createdAt: DateTime.now(),
        inviteCode: 'ABC',
        cycleStartDay: 1,
      );

      final updated = household.copyWith(cycleStartDay: 15);
      expect(updated.cycleStartDay, 15);
      expect(updated.name, 'House');
    });
  });
}
