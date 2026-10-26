import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/transaction_model.dart';
import '../household/current_household_provider.dart';
import 'models/category_budget.dart';

final categoryBudgetsProvider =
    NotifierProvider<CategoryBudgetsController, Map<String, double>>(
  CategoryBudgetsController.new,
);

class CategoryBudgetsController extends Notifier<Map<String, double>> {
  static const _prefix = 'category_budgets_';

  String _getStorageKey() {
    final household = ref.watch(currentHouseholdProvider).asData?.value;
    final householdId = household?.id ?? 'default';
    return '$_prefix$householdId';
  }

  @override
  Map<String, double> build() {
    _loadBudgets();
    return const {};
  }

  Future<void> _loadBudgets() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKey();
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final budgets = <String, double>{};
        decoded.forEach((k, v) {
          if (v is num && v > 0) {
            budgets[k.toLowerCase()] = v.toDouble();
          }
        });
        state = budgets;
      }
    } catch (_) {
      // Graceful fallback to empty map
    }
  }

  Future<void> setBudget(String categoryId, double amount) async {
    final normalized = categoryId.toLowerCase().trim();
    final updated = Map<String, double>.from(state);
    if (amount <= 0) {
      updated.remove(normalized);
    } else {
      updated[normalized] = amount;
    }
    state = updated;
    await _persist(updated);
  }

  Future<void> removeBudget(String categoryId) async {
    final normalized = categoryId.toLowerCase().trim();
    final updated = Map<String, double>.from(state)..remove(normalized);
    state = updated;
    await _persist(updated);
  }

  Future<void> saveAllBudgets(Map<String, double> newBudgets) async {
    final filtered = <String, double>{};
    newBudgets.forEach((k, v) {
      if (v > 0) {
        filtered[k.toLowerCase().trim()] = v;
      }
    });
    state = filtered;
    await _persist(filtered);
  }

  Future<void> clearAll() async {
    state = const {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_getStorageKey());
  }

  Future<void> _persist(Map<String, double> map) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKey();
      await prefs.setString(key, jsonEncode(map));
    } catch (_) {}
  }
}

/// Provider helper that evaluates active transactions against category budgets
final categoryBudgetStatusesProvider =
    Provider.family<List<CategoryBudgetStatus>, List<TransactionModel>>(
  (ref, transactions) {
    final budgets = ref.watch(categoryBudgetsProvider);
    if (budgets.isEmpty) return const [];

    // Aggregate spending by category for expense transactions
    final spending = <String, double>{};
    for (final tx in transactions) {
      if (tx.type == TransactionType.paid && tx.category.toLowerCase() != 'settlement') {
        final key = tx.category.toLowerCase().trim();
        spending[key] = (spending[key] ?? 0.0) + tx.amount;
      }
    }

    final statuses = <CategoryBudgetStatus>[];
    for (final entry in budgets.entries) {
      final catId = entry.key;
      final budgetLimit = entry.value;
      final spent = spending[catId] ?? 0.0;
      statuses.add(
        CategoryBudgetStatus(
          categoryId: catId,
          budget: budgetLimit,
          spent: spent,
        ),
      );
    }

    // Sort by most critical: exceeded first, then highest percentage
    statuses.sort((a, b) => b.percentage.compareTo(a.percentage));
    return statuses;
  },
);
