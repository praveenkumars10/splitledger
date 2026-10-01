import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/date_filters.dart';
import '../../core/group_split_calculator.dart';
import '../../models/transaction_model.dart';
import '../auth/auth_controller.dart';
import '../household/current_household_provider.dart';
import '../transactions/transaction_repository.dart';

class SplitSummaryPage extends ConsumerStatefulWidget {
  const SplitSummaryPage({super.key});

  @override
  ConsumerState<SplitSummaryPage> createState() => _SplitSummaryPageState();
}

class _SplitSummaryPageState extends ConsumerState<SplitSummaryPage> {
  DateTime _selectedMonth = DateTime.now();
  bool _allTime = false;

  final _monthFormat = DateFormat('MMM yyyy');
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9');

  Future<void> _selectMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month);
        _allTime = false;
      });
    }
  }

  Future<void> _recordSettlement(SettlementTransaction s, String householdId, String currentUid, String currentName) async {
    final messenger = ScaffoldMessenger.of(context);
    final tx = TransactionModel(
      id: '',
      amount: s.amount,
      category: 'settlement',
      paidByUid: currentUid,
      paidByName: currentName,
      note: 'Settlement: ${s.from} paid ${s.to}',
      date: DateTime.now(),
      type: TransactionType.received,
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(transactionRepositoryProvider).addTransaction(householdId, tx);
      messenger.showSnackBar(
        SnackBar(content: Text('Recorded settlement of ${_currencyFormat.format(s.amount)}!')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to record settlement: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(currentTransactionsProvider);
    final currentUser = ref.watch(authStateChangesProvider).asData?.value;
    final household = ref.watch(currentHouseholdProvider).asData?.value;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: const Text('Split Summary'),
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (transactions) {
          if (currentUser == null) return const Center(child: Text('Not signed in'));

          final periodTransactions = _allTime
              ? transactions
              : transactions.where((tx) => isInMonth(tx.date, _selectedMonth)).toList();

          final groupMembers = household?.members.map((m) => (uid: m.uid, name: m.name)).toList() ?? [];
          final split = calculateGroupSplit(
            transactions: periodTransactions,
            members: groupMembers,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Period selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('All Time'),
                      selected: _allTime,
                      onSelected: (selected) => setState(() => _allTime = selected),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(_allTime ? 'Pick Month' : _monthFormat.format(_selectedMonth)),
                      selected: !_allTime,
                      onSelected: (selected) {
                        if (selected) {
                          _selectMonth();
                        }
                      },
                    ),
                    if (!_allTime) ...[
                      IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => setState(() {
                          _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                        }),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => setState(() {
                          _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                        }),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),

                // Total Expense Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Text(
                          _allTime ? 'Total Group Expense' : 'Expense in ${_monthFormat.format(_selectedMonth)}',
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currencyFormat.format(split.totalExpense),
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Break down
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: split.balances.map((b) {
                    final color = Colors.primaries[split.balances.indexOf(b) % Colors.primaries.length];
                    return SizedBox(
                      width: (MediaQuery.of(context).size.width - 32 - 16) / 2,
                      child: _buildBreakdownCard(
                        title: '${b.name} Paid',
                        amount: b.paid,
                        color: color,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),

                // Settlement Result
                const Text('Settlements', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                if (split.isSettled)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 48),
                        SizedBox(height: 16),
                        Text(
                          'No due. You are all settled up! 🎉',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  ...split.settlements.map((s) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.handshake_outlined, color: Colors.red),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                s.toString(),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (household != null)
                          FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green.shade50,
                              foregroundColor: Colors.green.shade800,
                              side: BorderSide(color: Colors.green.shade200),
                            ),
                            onPressed: () => _recordSettlement(s, household.id, currentUser.uid, currentUser.displayName ?? 'You'),
                            child: Text('Mark as Paid / Settle ${_currencyFormat.format(s.amount)}'),
                          ),
                      ],
                    ),
                  )),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBreakdownCard({required String title, required double amount, required Color color}) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(title, style: TextStyle(color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              _currencyFormat.format(amount),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
