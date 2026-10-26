import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_ledger/features/budget/models/category_budget.dart';
import 'package:split_ledger/models/transaction_model.dart';

void main() {
  group('CategoryBudgetStatus Calculations & Health Classification', () {
    test('Healthy spending under 80% shows good health and emerald color', () {
      const status = CategoryBudgetStatus(
        categoryId: 'food',
        budget: 5000.0,
        spent: 3000.0,
      );

      expect(status.remaining, 2000.0);
      expect(status.overAmount, 0.0);
      expect(status.percentage, 60.0);
      expect(status.progressRatio, 0.6);
      expect(status.health, BudgetHealth.good);
      expect(status.isOverBudget, isFalse);
      expect(status.isNearLimit, isFalse);
      expect(status.statusColor, const Color(0xFF10B981));
    });

    test('Warning state at >=80% and <100% triggers nearLimit', () {
      const status = CategoryBudgetStatus(
        categoryId: 'fuel',
        budget: 2000.0,
        spent: 1700.0, // 85%
      );

      expect(status.remaining, 300.0);
      expect(status.overAmount, 0.0);
      expect(status.percentage, 85.0);
      expect(status.progressRatio, 0.85);
      expect(status.health, BudgetHealth.warning);
      expect(status.isOverBudget, isFalse);
      expect(status.isNearLimit, isTrue);
      expect(status.statusColor, const Color(0xFFF59E0B));
    });

    test('Over budget at >=100% triggers exceeded state and clamps ratio to 1.0', () {
      const status = CategoryBudgetStatus(
        categoryId: 'shopping',
        budget: 4000.0,
        spent: 5200.0, // 130%
      );

      expect(status.remaining, -1200.0);
      expect(status.overAmount, 1200.0);
      expect(status.percentage, 130.0);
      expect(status.progressRatio, 1.0); // clamped to 1.0
      expect(status.health, BudgetHealth.exceeded);
      expect(status.isOverBudget, isTrue);
      expect(status.isNearLimit, isFalse);
      expect(status.statusColor, const Color(0xFFEF4444));
    });

    test('Zero budget handles edge cases gracefully without dividing by zero', () {
      const status = CategoryBudgetStatus(
        categoryId: 'other',
        budget: 0.0,
        spent: 500.0,
      );

      expect(status.percentage, 0.0);
      expect(status.progressRatio, 0.0);
      expect(status.isOverBudget, isTrue);
    });
  });

  group('Category Budget Transaction Evaluation Logic', () {
    test('Calculates total spending for each category from transactions', () {
      final now = DateTime.now();
      final transactions = [
        TransactionModel(
          id: '1',
          paidByUid: 'user1',
          paidByName: 'Praveen',
          type: TransactionType.paid,
          category: 'food',
          amount: 1200.0,
          date: now,
          createdAt: now,
        ),
        TransactionModel(
          id: '2',
          paidByUid: 'user2',
          paidByName: 'Kumar',
          type: TransactionType.paid,
          category: 'food',
          amount: 800.0,
          date: now,
          createdAt: now,
        ),
        TransactionModel(
          id: '3',
          paidByUid: 'user1',
          paidByName: 'Praveen',
          type: TransactionType.paid,
          category: 'fuel',
          amount: 2500.0,
          date: now,
          createdAt: now,
        ),
        // Received should NOT count towards expense budget
        TransactionModel(
          id: '4',
          paidByUid: 'user1',
          paidByName: 'Praveen',
          type: TransactionType.received,
          category: 'other',
          amount: 5000.0,
          date: now,
          createdAt: now,
        ),
        // Settlements should NOT count towards category spending
        TransactionModel(
          id: '5',
          paidByUid: 'user2',
          paidByName: 'Kumar',
          type: TransactionType.paid,
          category: 'settlement',
          amount: 1500.0,
          date: now,
          createdAt: now,
        ),
      ];

      // Simulate spending calculation
      final spending = <String, double>{};
      for (final tx in transactions) {
        if (tx.type == TransactionType.paid && tx.category.toLowerCase() != 'settlement') {
          final key = tx.category.toLowerCase().trim();
          spending[key] = (spending[key] ?? 0.0) + tx.amount;
        }
      }

      expect(spending['food'], 2000.0);
      expect(spending['fuel'], 2500.0);
      expect(spending['settlement'], isNull);
      expect(spending['other'], isNull);

      final foodStatus = CategoryBudgetStatus(
        categoryId: 'food',
        budget: 3000.0,
        spent: spending['food'] ?? 0.0,
      );
      expect(foodStatus.isOverBudget, isFalse);
      expect(foodStatus.remaining, 1000.0);

      final fuelStatus = CategoryBudgetStatus(
        categoryId: 'fuel',
        budget: 2000.0,
        spent: spending['fuel'] ?? 0.0,
      );
      expect(fuelStatus.isOverBudget, isTrue);
      expect(fuelStatus.overAmount, 500.0);
    });
  });
}
