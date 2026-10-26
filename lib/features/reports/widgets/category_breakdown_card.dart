import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/categories.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/language_controller.dart';
import '../../../models/transaction_model.dart';
import '../../budget/category_budget_controller.dart';
import '../../budget/widgets/category_budget_dialog.dart';

class CategoryBreakdownCard extends ConsumerWidget {
  final List<TransactionModel> transactions;

  const CategoryBreakdownCard({super.key, required this.transactions});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageControllerProvider);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onSurfaceVariant = colorScheme.onSurfaceVariant;
    final budgets = ref.watch(categoryBudgetsProvider);

    // Filter only spent/expense transactions (TransactionType.paid)
    final expenseTransactions = transactions
        .where((t) => t.type == TransactionType.paid && t.category.toLowerCase() != 'settlement')
        .toList();

    if (expenseTransactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final double totalSpend = expenseTransactions.fold(0.0, (sum, t) => sum + t.amount);
    if (totalSpend <= 0) return const SizedBox.shrink();

    // Aggregate by category
    final Map<String, double> categoryTotals = {};
    for (final t in expenseTransactions) {
      final key = t.category.toLowerCase().trim();
      categoryTotals[key] = (categoryTotals[key] ?? 0.0) + t.amount;
    }

    // Sort descending by amount
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.pie_chart, color: colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.tr(language, 'category_spending_breakdown'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Total: ${currencyFormat.format(totalSpend)}',
                        style: TextStyle(fontSize: 12, color: onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => CategoryBudgetDialog.show(
                    context,
                    currentPeriodTransactions: transactions,
                  ),
                  icon: const Icon(Icons.tune, size: 16),
                  label: Text(
                    AppStrings.tr(language, 'manage_budgets'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...sortedCategories.map((entry) {
              final catKey = entry.key;
              final amount = entry.value;
              final percentageOfTotal = (amount / totalSpend) * 100;

              final appCat = getCategoryById(catKey);
              final icon = appCat.icon;
              final color = appCat.color;
              final label = appCat.getLocalizedName(language);

              final budgetLimit = budgets[catKey];
              final hasBudget = budgetLimit != null && budgetLimit > 0;
              final budgetRatio = hasBudget ? (amount / budgetLimit) : 0.0;
              final isOverBudget = hasBudget && amount > budgetLimit;
              final isNearBudget = hasBudget && budgetRatio >= 0.8 && !isOverBudget;

              final Color progressColor = isOverBudget
                  ? const Color(0xFFEF4444)
                  : (isNearBudget ? const Color(0xFFF59E0B) : color);

              return Padding(
                padding: const EdgeInsets.only(bottom: 14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, color: color, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      label,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isOverBudget) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${AppStrings.tr(language, 'over_by')} ${currencyFormat.format(amount - budgetLimit)}',
                                        style: const TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (hasBudget)
                                Text(
                                  '${currencyFormat.format(amount)} / ${currencyFormat.format(budgetLimit)} (${(budgetRatio * 100).toStringAsFixed(0)}%)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isOverBudget ? Colors.red : (isNearBudget ? Colors.amber.shade900 : onSurfaceVariant),
                                    fontWeight: isOverBudget || isNearBudget ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                )
                              else
                                Text(
                                  '${percentageOfTotal.toStringAsFixed(1)}% of total spend',
                                  style: TextStyle(fontSize: 11, color: onSurfaceVariant),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currencyFormat.format(amount),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isOverBudget ? Colors.red.shade700 : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: hasBudget
                            ? budgetRatio.clamp(0.0, 1.0)
                            : (percentageOfTotal / 100).clamp(0.0, 1.0),
                        backgroundColor: progressColor.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
