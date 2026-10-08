import 'package:flutter_test/flutter_test.dart';
import 'package:split_ledger/core/group_split_calculator.dart';
import 'package:split_ledger/models/transaction_model.dart';

TransactionModel _tx({
  required String id,
  required String paidByUid,
  required String paidByName,
  required double amount,
  String category = 'General',
  TransactionType type = TransactionType.paid,
  DateTime? date,
}) {
  return TransactionModel(
    id: id,
    amount: amount,
    category: category,
    paidByUid: paidByUid,
    paidByName: paidByName,
    date: date ?? DateTime(2026, 7, 20),
    createdAt: date ?? DateTime(2026, 7, 20),
    type: type,
  );
}

void main() {
  const a = (uid: 'a', name: 'User A');
  const b = (uid: 'b', name: 'User B');
  const c = (uid: 'c', name: 'User C');
  const d = (uid: 'd', name: 'User D');
  const e = (uid: 'e', name: 'User E');

  group('2 members', () {
    test('one person pays everything', () {
      final result = calculateGroupSplit(
        transactions: [_tx(id: '1', paidByUid: 'a', paidByName: 'User A', amount: 1000)],
        members: [a, b],
      );

      expect(result.totalExpense, 1000);
      expect(result.individualShare, 500);
      expect(result.balancesSumToZero, isTrue);
      expect(result.settlementAmountsMatch, isTrue);
      expect(result.settlements.length, 1);
      expect(result.settlements.first.from, 'User B');
      expect(result.settlements.first.to, 'User A');
      expect(result.settlements.first.amount, 500);
    });

    test('everyone pays equally -> settled', () {
      final result = calculateGroupSplit(
        transactions: [
          _tx(id: '1', paidByUid: 'a', paidByName: 'User A', amount: 1000),
          _tx(id: '2', paidByUid: 'b', paidByName: 'User B', amount: 1000),
        ],
        members: [a, b],
      );

      expect(result.totalExpense, 2000);
      expect(result.individualShare, 1000);
      expect(result.isSettled, isTrue);
      expect(result.balancesSumToZero, isTrue);
    });

    test('different amounts', () {
      final result = calculateGroupSplit(
        transactions: [
          _tx(id: '1', paidByUid: 'a', paidByName: 'User A', amount: 1000),
          _tx(id: '2', paidByUid: 'b', paidByName: 'User B', amount: 500),
        ],
        members: [a, b],
      );

      expect(result.totalExpense, 1500);
      expect(result.individualShare, 750);
      expect(result.settlements.length, 1);
      expect(result.settlements.first.from, 'User B');
      expect(result.settlements.first.to, 'User A');
      expect(result.settlements.first.amount, 250);
    });

    test('decimals', () {
      final result = calculateGroupSplit(
        transactions: [
          _tx(id: '1', paidByUid: 'a', paidByName: 'User A', amount: 99.99),
          _tx(id: '2', paidByUid: 'b', paidByName: 'User B', amount: 123.45),
        ],
        members: [a, b],
      );

      expect(result.totalExpense, closeTo(223.44, 0.001));
      expect(result.individualShare, closeTo(111.72, 0.001));
      expect(result.balancesSumToZero, isTrue);
      expect(result.settlementAmountsMatch, isTrue);
    });

    test('zero expenses', () {
      final result = calculateGroupSplit(transactions: [], members: [a, b]);
      expect(result.totalExpense, 0);
      expect(result.isSettled, isTrue);
      expect(result.balancesSumToZero, isTrue);
    });

    test('received transaction reduces payer net paid and acts as a settlement', () {
      final result = calculateGroupSplit(
        transactions: [
          _tx(id: '1', paidByUid: 'a', paidByName: 'User A', amount: 1000),
          _tx(id: '2', paidByUid: 'a', paidByName: 'User A', amount: 200, type: TransactionType.received),
        ],
        members: [a, b],
      );

      expect(result.totalExpense, 1000);
      expect(result.individualShare, 500);
      expect(result.settlements.first.from, 'User B');
      expect(result.settlements.first.amount, 300);
    });
  });

  group('3 members', () {
    test('one person pays everything', () {
      final result = calculateGroupSplit(
        transactions: [_tx(id: '1', paidByUid: 'a', paidByName: 'User A', amount: 900)],
        members: [a, b, c],
      );

      expect(result.totalExpense, 900);
      expect(result.individualShare, 300);
      expect(result.settlements.length, 2);
      expect(result.balancesSumToZero, isTrue);
    });

    test('everyone pays equally', () {
      final result = calculateGroupSplit(
        transactions: [
          _tx(id: '1', paidByUid: 'a', paidByName: 'User A', amount: 300),
          _tx(id: '2', paidByUid: 'b', paidByName: 'User B', amount: 300),
          _tx(id: '3', paidByUid: 'c', paidByName: 'User C', amount: 300),
        ],
        members: [a, b, c],
      );

      expect(result.isSettled, isTrue);
    });

    test('different amounts', () {
      final result = calculateGroupSplit(
        transactions: [
          _tx(id: '1', paidByUid: 'a', paidByName: 'User A', amount: 1000),
          _tx(id: '2', paidByUid: 'b', paidByName: 'User B', amount: 500),
          _tx(id: '3', paidByUid: 'c', paidByName: 'User C', amount: 0),
        ],
        members: [a, b, c],
      );

      expect(result.totalExpense, 1500);
      expect(result.individualShare, 500);
      final balanceA = result.balances.firstWhere((x) => x.uid == 'a').net;
      final balanceB = result.balances.firstWhere((x) => x.uid == 'b').net;
      final balanceC = result.balances.firstWhere((x) => x.uid == 'c').net;
      expect(balanceA, 500);
      expect(balanceB, 0);
      expect(balanceC, -500);
      expect(result.settlements.length, 1);
      expect(result.settlements.first.from, 'User C');
      expect(result.settlements.first.to, 'User A');
      expect(result.settlements.first.amount, 500);
    });
  });

  group('4 members', () {
    test('minimizes settlement transactions', () {
      final result = calculateGroupSplit(
        transactions: [
          _tx(id: '1', paidByUid: 'a', paidByName: 'User A', amount: 1200),
          _tx(id: '2', paidByUid: 'b', paidByName: 'User B', amount: 400),
        ],
        members: [a, b, c, d],
      );

      expect(result.totalExpense, 1600);
      expect(result.individualShare, 400);
      expect(result.settlements.length, 2);
      expect(result.balancesSumToZero, isTrue);
    });
  });

  group('5+ members', () {
    test('settlement sums to zero', () {
      final result = calculateGroupSplit(
        transactions: [
          _tx(id: '1', paidByUid: 'a', paidByName: 'User A', amount: 2500),
          _tx(id: '2', paidByUid: 'b', paidByName: 'User B', amount: 1000),
          _tx(id: '3', paidByUid: 'c', paidByName: 'User C', amount: 500),
        ],
        members: [a, b, c, d, e],
      );

      expect(result.totalExpense, 4000);
      expect(result.individualShare, 800);
      expect(result.balancesSumToZero, isTrue);
      expect(result.settlementAmountsMatch, isTrue);
    });
  });

  group('edge cases', () {
    test('very large expenses', () {
      final result = calculateGroupSplit(
        transactions: [
          _tx(id: '1', paidByUid: 'a', paidByName: 'User A', amount: 1000000),
          _tx(id: '2', paidByUid: 'b', paidByName: 'User B', amount: 500000),
        ],
        members: [a, b],
      );

      expect(result.totalExpense, 1500000);
      expect(result.individualShare, 750000);
      expect(result.settlements.first.amount, 250000);
    });

    test('multiple expenses same day same user', () {
      final result = calculateGroupSplit(
        transactions: [
          _tx(id: '1', paidByUid: 'a', paidByName: 'User A', amount: 200),
          _tx(id: '2', paidByUid: 'a', paidByName: 'User A', amount: 300),
          _tx(id: '3', paidByUid: 'b', paidByName: 'User B', amount: 100),
        ],
        members: [a, b],
      );

      expect(result.totalExpense, 600);
      expect(result.individualShare, 300);
      expect(result.settlements.first.amount, 200);
    });

    test('empty members list', () {
      final result = calculateGroupSplit(transactions: [], members: []);
      expect(result.totalExpense, 0);
      expect(result.isSettled, isTrue);
    });

    test('3 members direct settlement with counterpartyUid settles correct pair', () {
      final result = calculateGroupSplit(
        transactions: [
          // A pays 300 for the group (A, B, C share 100 each)
          _tx(id: '1', paidByUid: 'a', paidByName: 'User A', amount: 300),
          // B settles with A directly: gives 100 to A
          TransactionModel(
            id: '2',
            amount: 100,
            category: 'settlement',
            paidByUid: 'a',
            paidByName: 'User A',
            counterpartyUid: 'b',
            date: DateTime.now(),
            type: TransactionType.received,
            createdAt: DateTime.now(),
          ),
        ],
        members: [a, b, c],
      );

      final balanceA = result.balances.firstWhere((b) => b.uid == 'a');
      final balanceB = result.balances.firstWhere((b) => b.uid == 'b');
      final balanceC = result.balances.firstWhere((b) => b.uid == 'c');

      expect(balanceB.net, 0.0); // B is completely settled!
      expect(balanceA.net, 100.0); // A is still owed 100 (from C)
      expect(balanceC.net, -100.0); // C still owes 100
      expect(result.settlements.length, 1);
      expect(result.settlements.first.from, 'User C');
      expect(result.settlements.first.to, 'User A');
    });
  });

  group('wallet balance calculation', () {
    test('calculates remaining balance from initial wallet (e.g. 2k)', () {
      const double walletAmount = 2000;
      final txs = [
        _tx(id: '1', paidByUid: 'a', paidByName: 'User A', amount: 500, type: TransactionType.paid),
        _tx(id: '2', paidByUid: 'a', paidByName: 'User A', amount: 200, type: TransactionType.received),
      ];

      double totalPaid = 0;
      double totalReceived = 0;
      for (final tx in txs) {
        if (tx.type == TransactionType.paid) {
          totalPaid += tx.amount;
        } else {
          totalReceived += tx.amount;
        }
      }

      final remainingBalance = walletAmount - totalPaid + totalReceived;
      expect(totalPaid, 500);
      expect(totalReceived, 200);
      expect(remainingBalance, 1700);
    });
  });
}


