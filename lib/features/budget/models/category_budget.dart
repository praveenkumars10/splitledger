import 'package:flutter/material.dart';

enum BudgetHealth {
  good,     // < 80%
  warning,  // 80% - 99.9%
  exceeded, // >= 100%
}

class CategoryBudgetStatus {
  final String categoryId;
  final double budget;
  final double spent;

  const CategoryBudgetStatus({
    required this.categoryId,
    required this.budget,
    required this.spent,
  });

  double get remaining => budget - spent;
  double get overAmount => spent > budget ? spent - budget : 0.0;
  double get percentage => budget > 0 ? (spent / budget) * 100 : 0.0;
  double get progressRatio => budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;

  BudgetHealth get health {
    if (spent >= budget) return BudgetHealth.exceeded;
    if (percentage >= 80.0) return BudgetHealth.warning;
    return BudgetHealth.good;
  }

  Color get statusColor {
    switch (health) {
      case BudgetHealth.exceeded:
        return const Color(0xFFEF4444); // Red
      case BudgetHealth.warning:
        return const Color(0xFFF59E0B); // Amber / Orange
      case BudgetHealth.good:
        return const Color(0xFF10B981); // Emerald Green
    }
  }

  bool get isOverBudget => health == BudgetHealth.exceeded;
  bool get isNearLimit => health == BudgetHealth.warning;
}
