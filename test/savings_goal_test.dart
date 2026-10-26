import 'package:flutter_test/flutter_test.dart';
import 'package:split_ledger/features/savings/models/savings_goal_model.dart';

void main() {
  group('SavingsGoalModel Unit Tests', () {
    test('Calculates remaining amount, percentage, and progress ratio correctly', () {
      final now = DateTime(2026, 10, 26);
      final goal = SavingsGoalModel(
        id: 'goal_1',
        householdId: 'h_1',
        title: 'Emergency Fund',
        targetAmount: 50000.0,
        currentAmount: 20000.0,
        createdAt: now,
      );

      expect(goal.remainingAmount, 30000.0);
      expect(goal.percentage, 40.0);
      expect(goal.progressRatio, 0.4);
      expect(goal.isCompleted, isFalse);
    });

    test('Completed goal clamps progress to 1.0 and marks isCompleted', () {
      final now = DateTime(2026, 10, 26);
      final goal = SavingsGoalModel(
        id: 'goal_2',
        householdId: 'h_1',
        title: 'Goa Trip',
        targetAmount: 15000.0,
        currentAmount: 18000.0, // exceeded
        createdAt: now,
      );

      expect(goal.remainingAmount, 0.0);
      expect(goal.percentage, 120.0);
      expect(goal.progressRatio, 1.0);
      expect(goal.isCompleted, isTrue);
    });

    test('Zero target amount handles division safely', () {
      final goal = SavingsGoalModel(
        id: 'goal_3',
        householdId: 'h_1',
        title: 'Test',
        targetAmount: 0.0,
        currentAmount: 500.0,
        createdAt: DateTime.now(),
      );

      expect(goal.percentage, 0.0);
      expect(goal.progressRatio, 0.0);
      expect(goal.isCompleted, isTrue);
    });

    test('Serialization and Deserialization preserve all fields', () {
      final now = DateTime(2026, 10, 26, 15, 0, 0);
      final targetDate = DateTime(2027, 5, 1);
      final original = SavingsGoalModel(
        id: 'goal_json',
        householdId: 'house_abc',
        title: 'New MacBook Pro',
        targetAmount: 180000.0,
        currentAmount: 45000.0,
        targetDate: targetDate,
        emoji: '💻',
        colorValue: 0xFF3B82F6,
        notes: 'Targeting next Diwali',
        createdAt: now,
      );

      final map = original.toMap();
      final restored = SavingsGoalModel.fromMap(map, docId: 'goal_json');

      expect(restored.id, original.id);
      expect(restored.householdId, original.householdId);
      expect(restored.title, original.title);
      expect(restored.targetAmount, 180000.0);
      expect(restored.currentAmount, 45000.0);
      expect(restored.targetDate, targetDate);
      expect(restored.emoji, '💻');
      expect(restored.colorValue, 0xFF3B82F6);
      expect(restored.notes, 'Targeting next Diwali');
    });
  });
}
