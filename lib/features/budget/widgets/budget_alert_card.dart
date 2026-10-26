import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/categories.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/language_controller.dart';
import '../../../models/transaction_model.dart';
import '../category_budget_controller.dart';
import 'category_budget_dialog.dart';

class BudgetAlertCard extends ConsumerWidget {
  final List<TransactionModel> transactions;

  const BudgetAlertCard({
    super.key,
    required this.transactions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(categoryBudgetStatusesProvider(transactions));
    if (statuses.isEmpty) return const SizedBox.shrink();

    final exceeded = statuses.where((s) => s.isOverBudget).toList();
    final nearLimit = statuses.where((s) => s.isNearLimit).toList();

    if (exceeded.isEmpty && nearLimit.isEmpty) {
      return const SizedBox.shrink();
    }

    final language = ref.watch(languageControllerProvider);
    final isCritical = exceeded.isNotEmpty;
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    final primaryColor = isCritical ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    final bgColor = isCritical ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB);
    final borderColor = isCritical ? const Color(0xFFFCA5A5) : const Color(0xFFFDE68A);

    final title = isCritical
        ? '${AppStrings.tr(language, 'budget_alert_over')} (${exceeded.length})'
        : '${AppStrings.tr(language, 'budget_alert_near')} (${nearLimit.length})';

    final itemsToShow = isCritical ? exceeded : nearLimit;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => CategoryBudgetDialog.show(
              context,
              currentPeriodTransactions: transactions,
            ),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isCritical ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
                          color: primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: isCritical ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: primaryColor, size: 20),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...itemsToShow.take(2).map((item) {
                    final cat = getCategoryById(item.categoryId);
                    final catName = cat.getLocalizedName(language);
                    final percentStr = '${item.percentage.toStringAsFixed(0)}%';
                    final detail = isCritical
                        ? '${AppStrings.tr(language, 'over_by')} ${currencyFormat.format(item.overAmount)} ($percentStr)'
                        : '${currencyFormat.format(item.spent)} / ${currencyFormat.format(item.budget)} ($percentStr)';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(cat.emoji, style: const TextStyle(fontSize: 14)),
                                  const SizedBox(width: 6),
                                  Text(
                                    catName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: isCritical ? const Color(0xFF7F1D1D) : const Color(0xFF78350F),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                detail,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: item.progressRatio,
                              backgroundColor: primaryColor.withValues(alpha: 0.15),
                              valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                              minHeight: 5,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (itemsToShow.length > 2)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        '+ ${itemsToShow.length - 2} more categories',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isCritical ? const Color(0xFF991B1B) : const Color(0xFF92400E),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
