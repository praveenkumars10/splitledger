import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/categories.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/language_controller.dart';
import '../../../models/transaction_model.dart';
import '../category_budget_controller.dart';

class CategoryBudgetDialog extends ConsumerStatefulWidget {
  final List<TransactionModel>? currentPeriodTransactions;

  const CategoryBudgetDialog({
    super.key,
    this.currentPeriodTransactions,
  });

  static Future<void> show(
    BuildContext context, {
    List<TransactionModel>? currentPeriodTransactions,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CategoryBudgetDialog(
        currentPeriodTransactions: currentPeriodTransactions,
      ),
    );
  }

  @override
  ConsumerState<CategoryBudgetDialog> createState() => _CategoryBudgetDialogState();
}

class _CategoryBudgetDialogState extends ConsumerState<CategoryBudgetDialog> {
  late Map<String, TextEditingController> _controllers;
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _controllers = {};
    final existing = ref.read(categoryBudgetsProvider);
    for (final cat in appCategories) {
      if (cat.id == 'settle') continue;
      final val = existing[cat.id];
      _controllers[cat.id] = TextEditingController(
        text: val != null && val > 0 ? val.toStringAsFixed(0) : '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, double> _calculateCurrentSpending() {
    final spending = <String, double>{};
    if (widget.currentPeriodTransactions != null) {
      for (final tx in widget.currentPeriodTransactions!) {
        if (tx.type == TransactionType.paid && tx.category.toLowerCase() != 'settlement') {
          final key = tx.category.toLowerCase().trim();
          spending[key] = (spending[key] ?? 0.0) + tx.amount;
        }
      }
    }
    return spending;
  }

  void _saveAll() async {
    final updated = <String, double>{};
    for (final entry in _controllers.entries) {
      final text = entry.value.text.trim();
      final val = double.tryParse(text);
      if (val != null && val > 0) {
        updated[entry.key] = val;
      }
    }
    await ref.read(categoryBudgetsProvider.notifier).saveAllBudgets(updated);
    if (mounted) {
      final language = ref.read(languageControllerProvider);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.tr(language, 'budget_saved')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spending = _calculateCurrentSpending();

    final categories = appCategories.where((c) {
      if (c.id == 'settle') return false;
      if (_searchQuery.isEmpty) return true;
      final name = c.getLocalizedName(language).toLowerCase();
      return name.contains(_searchQuery.toLowerCase()) || c.id.contains(_searchQuery.toLowerCase());
    }).toList();

    double totalPlannedBudget = 0.0;
    for (final c in _controllers.values) {
      final val = double.tryParse(c.text.trim());
      if (val != null && val > 0) totalPlannedBudget += val;
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.tune_rounded, color: colorScheme.primary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.tr(language, 'category_budgets'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        AppStrings.tr(language, 'category_budgets_desc'),
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Total Planned Budget summary card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.15),
                    colorScheme.secondary.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet_outlined, color: colorScheme.primary, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        AppStrings.tr(language, 'budget_limit'),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                  Text(
                    totalPlannedBudget > 0 ? _currencyFormat.format(totalPlannedBudget) : '₹0',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search categories...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          const SizedBox(height: 8),

          // Category List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final controller = _controllers[cat.id]!;
                final currentSpent = spending[cat.id] ?? 0.0;
                final localizedName = cat.getLocalizedName(language);
                final budgetVal = double.tryParse(controller.text.trim()) ?? 0.0;
                final isOver = budgetVal > 0 && currentSpent > budgetVal;
                final isNear = budgetVal > 0 && (currentSpent / budgetVal) >= 0.8 && !isOver;

                return Card(
                  elevation: 0.5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isOver
                          ? Colors.red.withValues(alpha: 0.5)
                          : (isNear ? Colors.amber.withValues(alpha: 0.5) : colorScheme.outlineVariant.withValues(alpha: 0.4)),
                      width: isOver || isNear ? 1.5 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: cat.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(cat.emoji, style: const TextStyle(fontSize: 18)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        localizedName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      if (isOver) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            AppStrings.tr(language, 'budget_health_exceeded'),
                                            style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ] else if (isNear) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            AppStrings.tr(language, 'budget_health_warning'),
                                            style: TextStyle(color: Colors.amber.shade900, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (currentSpent > 0)
                                    Text(
                                      'Current spend: ${_currencyFormat.format(currentSpent)}',
                                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                                    ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 110,
                              child: TextField(
                                controller: controller,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.right,
                                decoration: InputDecoration(
                                  prefixText: '₹',
                                  hintText: '0',
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  filled: true,
                                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        // Quick chips for amounts
                        const SizedBox(height: 10),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ...[500, 1000, 2000, 5000, 10000].map((preset) {
                                final isSelected = controller.text.trim() == preset.toString();
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text('₹$preset', style: const TextStyle(fontSize: 11)),
                                    selected: isSelected,
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    onSelected: (sel) {
                                      setState(() {
                                        controller.text = sel ? preset.toString() : '';
                                      });
                                    },
                                  ),
                                );
                              }),
                              if (controller.text.isNotEmpty)
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      controller.clear();
                                    });
                                  },
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  child: const Text('Clear', style: TextStyle(color: Colors.red, fontSize: 11)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Bottom save action bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(AppStrings.tr(language, 'cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(
                        AppStrings.tr(language, 'save'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _saveAll,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
