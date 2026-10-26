import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/language_controller.dart';
import '../household/current_household_provider.dart';
import 'models/savings_goal_model.dart';
import 'savings_repository.dart';
import 'widgets/add_edit_goal_dialog.dart';

class SavingsPage extends ConsumerWidget {
  const SavingsPage({super.key});

  void _showDepositDialog(BuildContext context, WidgetRef ref, String householdId, SavingsGoalModel goal) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(goal.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(child: Text('Add Money to ${goal.title}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remaining needed: ₹${goal.remainingAmount.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                prefixText: '₹ ',
                hintText: 'Amount to deposit',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [500, 1000, 2000, 5000].map((amt) {
                return ActionChip(
                  label: Text('₹$amt', style: const TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => controller.text = amt.toString(),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final val = double.tryParse(controller.text.trim());
              if (val != null && val > 0) {
                Navigator.pop(ctx);
                await ref.read(savingsRepositoryProvider).depositToGoal(householdId, goal.id, val);
                if (context.mounted) {
                  final lang = ref.read(languageControllerProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppStrings.tr(lang, 'deposit_success')),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Add Money'),
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog(BuildContext context, WidgetRef ref, String householdId, SavingsGoalModel goal) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(goal.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(child: Text('Withdraw from ${goal.title}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Available: ₹${goal.currentAmount.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                prefixText: '₹ ',
                hintText: 'Amount to withdraw',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
            onPressed: () async {
              final val = double.tryParse(controller.text.trim());
              if (val != null && val > 0) {
                Navigator.pop(ctx);
                await ref.read(savingsRepositoryProvider).withdrawFromGoal(householdId, goal.id, val);
                if (context.mounted) {
                  final lang = ref.read(languageControllerProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppStrings.tr(lang, 'withdraw_success')),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final household = ref.watch(currentHouseholdProvider).asData?.value;
    final savingsAsync = ref.watch(currentSavingsGoalsProvider);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(language, 'savings_goals')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: AppStrings.tr(language, 'add_goal'),
            onPressed: () => AddEditGoalDialog.show(context),
          ),
        ],
      ),
      body: savingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (goals) {
          if (household == null) {
            return const Center(child: Text('No active household'));
          }

          final totalSaved = goals.fold(0.0, (sum, g) => sum + g.currentAmount);
          final totalTarget = goals.fold(0.0, (sum, g) => sum + g.targetAmount);
          final overallRatio = totalTarget > 0 ? (totalSaved / totalTarget).clamp(0.0, 1.0) : 0.0;
          final completedCount = goals.where((g) => g.isCompleted).length;

          return ListView(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 90),
            children: [
              // Portfolio Card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF059669), // Emerald
                      const Color(0xFF0284C7), // Sky Blue
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF059669).withValues(alpha: 0.3),
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
                              child: const Icon(Icons.savings_outlined, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Total Saved Portfolio',
                              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        if (completedCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$completedCount / ${goals.length} Achieved 🎉',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      currencyFormat.format(totalSaved),
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: overallRatio,
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        minHeight: 7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${(overallRatio * 100).toStringAsFixed(0)}% of target saved',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Target: ${currencyFormat.format(totalTarget)}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Piggy Banks & Goals',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => AddEditGoalDialog.show(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Goal'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (goals.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.savings_outlined, size: 64, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                      const SizedBox(height: 14),
                      Text(
                        AppStrings.tr(language, 'no_savings_goals'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: Text(AppStrings.tr(language, 'add_goal')),
                        onPressed: () => AddEditGoalDialog.show(context),
                      ),
                    ],
                  ),
                )
              else
                ...goals.map((goal) {
                  final goalColor = Color(goal.colorValue);
                  final isDone = goal.isCompleted;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 14),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isDone ? Colors.green.withValues(alpha: 0.6) : goalColor.withValues(alpha: 0.3),
                        width: isDone ? 1.5 : 1,
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
                                  color: goalColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(goal.emoji, style: const TextStyle(fontSize: 24)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            goal.title,
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isDone) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'Achieved! 🎉',
                                              style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      goal.targetDate != null
                                          ? 'Target: ${DateFormat('dd MMM yyyy').format(goal.targetDate!)}'
                                          : (goal.notes ?? 'Ongoing Savings'),
                                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, size: 20),
                                onSelected: (action) async {
                                  if (action == 'edit') {
                                    AddEditGoalDialog.show(context, existingGoal: goal);
                                  } else if (action == 'delete') {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete Savings Goal?'),
                                        content: Text('Remove "${goal.title}"? Your recorded transactions won\'t be affected.'),
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
                                      await ref.read(savingsRepositoryProvider).deleteGoal(household.id, goal.id);
                                    }
                                  }
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
                                  const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 18), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Progress numbers
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppStrings.tr(language, 'saved_amount'),
                                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                  ),
                                  Text(
                                    currencyFormat.format(goal.currentAmount),
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: goalColor),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    AppStrings.tr(language, 'target_amount'),
                                    style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                  ),
                                  Text(
                                    currencyFormat.format(goal.targetAmount),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: goal.progressRatio,
                              backgroundColor: goalColor.withValues(alpha: 0.15),
                              valueColor: AlwaysStoppedAnimation<Color>(goalColor),
                              minHeight: 7,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${goal.percentage.toStringAsFixed(0)}% reached',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: goalColor),
                              ),
                              if (!isDone)
                                Text(
                                  '₹${goal.remainingAmount.toStringAsFixed(0)} left to reach goal',
                                  style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 8),

                          // Action Buttons: Deposit & Withdraw
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  icon: const Icon(Icons.remove, size: 16),
                                  label: Text(AppStrings.tr(language, 'withdraw')),
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: goal.currentAmount > 0
                                      ? () => _showWithdrawDialog(context, ref, household.id, goal)
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: FilledButton.icon(
                                  icon: const Icon(Icons.add, size: 16),
                                  label: Text(
                                    AppStrings.tr(language, 'deposit'),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: goalColor,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => _showDepositDialog(context, ref, household.id, goal),
                                ),
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
        icon: const Icon(Icons.savings_outlined),
        label: Text(AppStrings.tr(language, 'add_goal')),
        onPressed: () => AddEditGoalDialog.show(context),
      ),
    );
  }
}
