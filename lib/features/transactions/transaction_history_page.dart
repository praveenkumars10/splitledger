import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils.dart';
import '../../models/transaction_model.dart';
import '../auth/auth_controller.dart';
import '../household/current_household_provider.dart';
import 'add_transaction_page.dart';
import 'transaction_repository.dart';

class TransactionHistoryPage extends ConsumerWidget {
  const TransactionHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(currentTransactionsProvider);
    final currentUser = ref.watch(authStateChangesProvider).asData?.value;
    final household = ref.watch(currentHouseholdProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (transactions) {
          if (transactions.isEmpty) {
            return const Center(child: Text('No transactions found.'));
          }

          final sorted = List<TransactionModel>.from(transactions)
            ..sort((a, b) => b.date.compareTo(a.date));

          return ListView.builder(
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final tx = sorted[index];
              final isMe = tx.paidByUid == currentUser?.uid;
              final isPaid = tx.type == TransactionType.paid;
              final amountColor = isPaid ? Colors.red.shade700 : Colors.green.shade700;
              final sign = isPaid ? '-' : '+';

              return Dismissible(
                key: ValueKey(tx.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                confirmDismiss: (_) async {
                  return await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete transaction?'),
                      content: const Text('This action cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (_) async {
                  if (household == null) return;
                  try {
                    await ref.read(transactionRepositoryProvider).deleteTransaction(household.id, tx.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Transaction deleted')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to delete: $e')),
                      );
                    }
                  }
                },
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: amountColor.withValues(alpha: 0.15),
                    child: Icon(
                      isPaid ? Icons.arrow_upward : Icons.arrow_downward,
                      color: amountColor,
                    ),
                  ),
                  title: Text(isPaid ? 'Paid' : 'Received', style: TextStyle(color: amountColor, fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${isMe ? "You" : shortName(tx.paidByName)} \u2022 ${DateFormat('dd MMM yyyy, hh:mm a').format(tx.date)}${tx.note?.isNotEmpty == true ? "\n${tx.note}" : ""}',
                  ),
                  isThreeLine: tx.note?.isNotEmpty == true,
                  trailing: Text(
                    '$sign\u20B9${tx.amount.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: amountColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddTransactionPage(
                          type: tx.type,
                          transaction: tx,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
