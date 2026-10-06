import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/language_controller.dart';
import '../../core/utils.dart';
import '../../models/transaction_model.dart';
import '../auth/auth_controller.dart';
import '../household/current_household_provider.dart';
import 'add_transaction_page.dart';
import 'transaction_repository.dart';

class TransactionHistoryPage extends ConsumerStatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  ConsumerState<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends ConsumerState<TransactionHistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedTypeFilter = 'all'; // all, paid, received

  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showTransactionDetails(TransactionModel tx, bool isMe, String partnerName) {
    final language = ref.read(languageControllerProvider);
    final isPaid = tx.type == TransactionType.paid;
    final amountColor = isPaid ? Colors.red.shade700 : Colors.green.shade700;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: amountColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(isPaid ? Icons.arrow_upward : Icons.arrow_downward, color: amountColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPaid ? AppStrings.tr(language, 'spend_cash_out') : AppStrings.tr(language, 'receive_cash_in'),
                          style: TextStyle(color: amountColor, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          _currencyFormat.format(tx.amount),
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              _buildDetailRow(AppStrings.tr(language, 'description'), tx.note?.isNotEmpty == true ? tx.note! : tx.category),
              _buildDetailRow(AppStrings.tr(language, 'category'), tx.category.toUpperCase()),
              _buildDetailRow(AppStrings.tr(language, 'by_header'), isMe ? AppStrings.tr(language, 'you') : (tx.paidByName.isNotEmpty ? tx.paidByName : partnerName)),
              _buildDetailRow(AppStrings.tr(language, 'date_time'), _dateFormat.format(tx.date)),
              if (tx.recurrence != RecurrenceInterval.none)
                _buildDetailRow(AppStrings.tr(language, 'repeat'), tx.recurrence.name.toUpperCase()),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.edit, size: 18),
                      label: Text(AppStrings.tr(language, 'edit')),
                      onPressed: () {
                        Navigator.pop(context);
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
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.delete, size: 18),
                      label: Text(AppStrings.tr(language, 'delete')),
                      onPressed: () async {
                        final household = ref.read(currentHouseholdProvider).asData?.value;
                        if (household != null) {
                          Navigator.pop(context);
                          await ref.read(transactionRepositoryProvider).deleteTransaction(household.id, tx.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppStrings.tr(language, 'tx_deleted'))),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: onSurfaceVariant, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(currentTransactionsProvider);
    final currentUser = ref.watch(authStateChangesProvider).asData?.value;
    final household = ref.watch(currentHouseholdProvider).asData?.value;
    final language = ref.watch(languageControllerProvider);
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(language, 'history_tab')),
        centerTitle: false,
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: AppStrings.tr(language, 'search_hint'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).cardColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),

          // Filter Segmented Chips (All / Paid / Received)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(AppStrings.tr(language, 'all_time')),
                  selected: _selectedTypeFilter == 'all',
                  onSelected: (val) {
                    if (val) setState(() => _selectedTypeFilter = 'all');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.arrow_upward, size: 14, color: Colors.red),
                  label: Text(AppStrings.tr(language, 'you_paid')),
                  selected: _selectedTypeFilter == 'paid',
                  onSelected: (val) {
                    if (val) setState(() => _selectedTypeFilter = 'paid');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.arrow_downward, size: 14, color: Colors.green),
                  label: Text(AppStrings.tr(language, 'you_received')),
                  selected: _selectedTypeFilter == 'received',
                  onSelected: (val) {
                    if (val) setState(() => _selectedTypeFilter = 'received');
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 16),

          // Transactions List
          Expanded(
            child: transactionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (transactions) {
                // Filter by search query
                var filtered = transactions.where((t) {
                  if (_searchQuery.isNotEmpty) {
                    final noteMatch = t.note?.toLowerCase().contains(_searchQuery) ?? false;
                    final categoryMatch = t.category.toLowerCase().contains(_searchQuery);
                    final nameMatch = t.paidByName.toLowerCase().contains(_searchQuery);
                    final amountMatch = t.amount.toString().contains(_searchQuery);
                    if (!noteMatch && !categoryMatch && !nameMatch && !amountMatch) return false;
                  }

                  if (_selectedTypeFilter == 'paid' && t.type != TransactionType.paid) return false;
                  if (_selectedTypeFilter == 'received' && t.type != TransactionType.received) return false;

                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: onSurfaceVariant.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? '${AppStrings.tr(language, 'no_matching_tx')} "$_searchQuery"'
                              : AppStrings.tr(language, 'no_transactions_yet'),
                          style: TextStyle(color: onSurfaceVariant, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                final sorted = List<TransactionModel>.from(filtered)
                  ..sort((a, b) => b.date.compareTo(a.date));

                return ListView.separated(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 90),
                  itemCount: sorted.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final tx = sorted[index];
                    final isMe = tx.paidByUid == currentUser?.uid;
                    final isPaid = tx.type == TransactionType.paid;
                    final amountColor = isPaid ? Colors.red.shade700 : Colors.green.shade700;
                    final sign = isPaid ? '-' : '+';
                    final title = tx.note?.isNotEmpty == true ? tx.note! : (tx.category.isEmpty ? AppStrings.tr(language, 'other') : tx.category[0].toUpperCase() + tx.category.substring(1));

                    return Dismissible(
                      key: ValueKey(tx.id),
                      direction: DismissDirection.horizontal,
                      background: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 20),
                        child: Row(
                          children: [
                            const Icon(Icons.edit, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(AppStrings.tr(language, 'edit'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      secondaryBackground: Container(
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(AppStrings.tr(language, 'delete'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            const Icon(Icons.delete, color: Colors.white),
                          ],
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          // Edit
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddTransactionPage(
                                type: tx.type,
                                transaction: tx,
                              ),
                            ),
                          );
                          return false;
                        } else {
                          // Delete
                          return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(AppStrings.tr(language, 'delete_tx_title')),
                              content: Text('${AppStrings.tr(language, 'delete_tx_confirm')}\n"${_currencyFormat.format(tx.amount)}" ($title)'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: Text(AppStrings.tr(language, 'cancel')),
                                ),
                                FilledButton(
                                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text(AppStrings.tr(language, 'delete')),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      onDismissed: (_) async {
                        if (household != null) {
                          await ref.read(transactionRepositoryProvider).deleteTransaction(household.id, tx.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(AppStrings.tr(language, 'tx_deleted'))),
                            );
                          }
                        }
                      },
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: amountColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPaid ? Icons.arrow_upward : Icons.arrow_downward,
                            color: amountColor,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${isMe ? AppStrings.tr(language, "you") : shortName(tx.paidByName)} • ${_dateFormat.format(tx.date)}',
                          style: TextStyle(fontSize: 12, color: onSurfaceVariant),
                        ),
                        trailing: Text(
                          '$sign${_currencyFormat.format(tx.amount)}',
                          style: TextStyle(
                            color: amountColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        onTap: () => _showTransactionDetails(tx, isMe, tx.paidByName),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
