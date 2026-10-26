import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/categories.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/language_controller.dart';
import '../household/current_household_provider.dart';
import '../transactions/transaction_repository.dart';
import 'recurring_repository.dart';
import 'widgets/add_edit_recurring_dialog.dart';

class RecurringPage extends ConsumerWidget {
  const RecurringPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final household = ref.watch(currentHouseholdProvider).asData?.value;
    final recurringAsync = ref.watch(currentRecurringExpensesProvider);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final now = DateTime.now();
    final currentCycleKey = DateFormat('yyyy-MM').format(now);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(language, 'recurring_expenses')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: AppStrings.tr(language, 'add_recurring'),
            onPressed: () => AddEditRecurringDialog.show(context),
          ),
        ],
      ),
      body: recurringAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (items) {
          if (household == null) {
            return const Center(child: Text('No active household'));
          }

          final activeItems = items.where((i) => i.isActive).toList();
          final totalMonthlyCommitment = activeItems.fold(0.0, (sum, i) => sum + i.amount);
          final paidThisCycle = activeItems
              .where((i) => i.isLoggedForCycle(currentCycleKey))
              .fold(0.0, (sum, i) => sum + i.amount);

          return ListView(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 90),
            children: [
              // Summary Banner Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.secondary,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.autorenew, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              AppStrings.tr(language, 'total_monthly_recurring'),
                              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${activeItems.length} active',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      currencyFormat.format(totalMonthlyCommitment),
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: totalMonthlyCommitment > 0 ? (paidThisCycle / totalMonthlyCommitment).clamp(0.0, 1.0) : 0.0,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Paid: ${currencyFormat.format(paidThisCycle)}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'Remaining: ${currencyFormat.format((totalMonthlyCommitment - paidThisCycle).clamp(0.0, totalMonthlyCommitment))}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subscriptions & Fixed Bills',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => AddEditRecurringDialog.show(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Bill'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (items.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 64, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                      const SizedBox(height: 14),
                      Text(
                        AppStrings.tr(language, 'no_recurring'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: Text(AppStrings.tr(language, 'add_recurring')),
                        onPressed: () => AddEditRecurringDialog.show(context),
                      ),
                    ],
                  ),
                )
              else
                ...items.map((item) {
                  final cat = getCategoryById(item.category);
                  final isLogged = item.isLoggedForCycle(currentCycleKey);
                  final daysLeft = item.daysUntilDue(now);
                  final isDueToday = daysLeft == 0;
                  final isDueSoon = daysLeft > 0 && daysLeft <= 3;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: isDueToday
                            ? Colors.red.withValues(alpha: 0.6)
                            : (isDueSoon ? Colors.amber.withValues(alpha: 0.6) : colorScheme.outlineVariant.withValues(alpha: 0.4)),
                        width: isDueToday || isDueSoon ? 1.5 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: cat.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(cat.emoji, style: const TextStyle(fontSize: 22)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        decoration: item.isActive ? null : TextDecoration.lineThrough,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Due: Day ${item.dueDay} of month • ${item.paidByName}',
                                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                currencyFormat.format(item.amount),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20),
                                onSelected: (action) async {
                                  if (action == 'edit') {
                                    AddEditRecurringDialog.show(context, existingItem: item);
                                  } else if (action == 'toggle') {
                                    final repo = ref.read(recurringRepositoryProvider);
                                    await repo.updateRecurringExpense(household.id, item.copyWith(isActive: !item.isActive));
                                  } else if (action == 'delete') {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete Recurring Expense?'),
                                        content: Text('Remove "${item.title}" from recurring commitments?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                          FilledButton(
                                            style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await ref.read(recurringRepositoryProvider).deleteRecurringExpense(household.id, item.id);
                                    }
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
                                  PopupMenuItem(value: 'toggle', child: Row(children: [Icon(item.isActive ? Icons.pause : Icons.play_arrow, size: 18), const SizedBox(width: 8), Text(item.isActive ? 'Pause' : 'Activate')])),
                                  const PopupMenuDivider(),
                                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 10),

                          // Status badge and 1-tap Log Button
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (isLogged)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.check_circle, size: 14, color: Colors.green),
                                      const SizedBox(width: 6),
                                      Text(
                                        AppStrings.tr(language, 'paid_this_cycle'),
                                        style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                )
                              else if (isDueToday)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.alarm, size: 14, color: Colors.red),
                                      const SizedBox(width: 6),
                                      Text(
                                        AppStrings.tr(language, 'due_today'),
                                        style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                )
                              else if (isDueSoon)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'Due in $daysLeft days',
                                    style: TextStyle(color: Colors.amber.shade900, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                )
                              else
                                Text(
                                  'Due in $daysLeft days',
                                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                                ),

                              // 1-Tap Log Action
                              if (!isLogged && item.isActive)
                                FilledButton.tonalIcon(
                                  icon: const Icon(Icons.post_add, size: 16),
                                  label: Text(
                                    AppStrings.tr(language, 'log_expense_now'),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  style: FilledButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  ),
                                  onPressed: () async {
                                    final txRepo = ref.read(transactionRepositoryProvider);
                                    await ref.read(recurringRepositoryProvider).logExpenseAsTransaction(
                                      householdId: household.id,
                                      item: item,
                                      txRepo: txRepo,
                                      cycleKey: currentCycleKey,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(AppStrings.tr(language, 'expense_logged_success')),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                )
                              else if (isLogged)
                                TextButton.icon(
                                  icon: const Icon(Icons.repeat, size: 16),
                                  label: const Text('Log Again', style: TextStyle(fontSize: 12)),
                                  onPressed: () async {
                                    final txRepo = ref.read(transactionRepositoryProvider);
                                    await ref.read(recurringRepositoryProvider).logExpenseAsTransaction(
                                      householdId: household.id,
                                      item: item,
                                      txRepo: txRepo,
                                      cycleKey: currentCycleKey,
                                    );
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: Text(AppStrings.tr(language, 'add_recurring')),
        onPressed: () => AddEditRecurringDialog.show(context),
      ),
    );
  }
}
