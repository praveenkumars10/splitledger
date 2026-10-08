import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/language_controller.dart';
import '../../../models/transaction_model.dart';

class CategoryBreakdownCard extends ConsumerWidget {
  final List<TransactionModel> transactions;

  const CategoryBreakdownCard({super.key, required this.transactions});

  static const Map<String, (IconData, Color)> categoryMeta = {
    'food': (Icons.restaurant, Color(0xFFF97316)),
    'fuel': (Icons.local_gas_station, Color(0xFFEF4444)),
    'tea': (Icons.coffee, Color(0xFF8B5CF6)),
    'grocery': (Icons.shopping_cart, Color(0xFF10B981)),
    'rent': (Icons.home, Color(0xFF3B82F6)),
    'bills': (Icons.receipt_long, Color(0xFF06B6D4)),
    'entertainment': (Icons.movie, Color(0xFFEC4899)),
    'shopping': (Icons.shopping_bag, Color(0xFFA855F7)),
    'medical': (Icons.medical_services, Color(0xFFE11D48)),
    'settle': (Icons.handshake, Color(0xFF0D9488)),
    'other': (Icons.category, Color(0xFF64748B)),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageControllerProvider);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

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
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.pie_chart, color: Theme.of(context).colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppStrings.tr(language, 'category_spending_breakdown'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  currencyFormat.format(totalSpend),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            ...sortedCategories.map((entry) {
              final catKey = entry.key;
              final amount = entry.value;
              final percentage = (amount / totalSpend) * 100;

              final meta = categoryMeta[catKey] ?? (Icons.category, const Color(0xFF64748B));
              final icon = meta.$1;
              final color = meta.$2;
              final label = AppStrings.tr(language, catKey).isNotEmpty && AppStrings.tr(language, catKey) != catKey
                  ? AppStrings.tr(language, catKey)
                  : (catKey.isEmpty ? AppStrings.tr(language, 'other') : catKey[0].toUpperCase() + catKey.substring(1));

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
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
                          child: Text(
                            label,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 12, color: onSurfaceVariant, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currencyFormat.format(amount),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (percentage / 100).clamp(0.0, 1.0),
                        backgroundColor: color.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
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
