import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/date_filters.dart';
import '../../core/group_split_calculator.dart';
import '../../core/services/upi_whatsapp_service.dart';
import '../../models/transaction_model.dart';
import '../auth/auth_controller.dart';
import '../household/current_household_provider.dart';
import '../reports/widgets/category_breakdown_card.dart';
import '../reports/widgets/daily_budget_card.dart';
import '../transactions/transaction_repository.dart';
import '../wallet/wallet_repository.dart';

class SplitSummaryPage extends ConsumerStatefulWidget {
  const SplitSummaryPage({super.key});

  @override
  ConsumerState<SplitSummaryPage> createState() => _SplitSummaryPageState();
}

class _SplitSummaryPageState extends ConsumerState<SplitSummaryPage> {
  DateTime _selectedMonth = DateTime.now();
  bool _allTime = false;

  final _monthFormat = DateFormat('MMM yyyy');
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

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
        SnackBar(
          content: Text('Recorded settlement of ${_currencyFormat.format(s.amount)}!'),
          backgroundColor: Colors.green,
        ),
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
    final walletAmount = ref.watch(currentWalletAmountProvider).asData?.value ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: const Text('Split & Settlement Hub'),
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

          final myName = currentUser.displayName ?? 'You';

          // User's total spend for daily budget card
          final userSpend = periodTransactions
              .where((t) => t.paidByUid == currentUser.uid && t.type == TransactionType.paid && t.category.toLowerCase() != 'settlement')
              .fold(0.0, (sum, t) => sum + t.amount);

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
                const SizedBox(height: 16),

                // Daily Budget Card
                DailyBudgetCard(
                  walletAmount: walletAmount,
                  userTotalSpend: userSpend,
                ),
                const SizedBox(height: 16),

                // Total Expense Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          _allTime ? 'Total Group Expense' : 'Total Group Expense (${_monthFormat.format(_selectedMonth)})',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _currencyFormat.format(split.totalExpense),
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Breakdown cards
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: split.balances.map((b) {
                    final color = Colors.primaries[split.balances.indexOf(b) % Colors.primaries.length];
                    return SizedBox(
                      width: (MediaQuery.of(context).size.width - 32 - 12) / 2,
                      child: _buildBreakdownCard(
                        title: '${b.name} Paid',
                        amount: b.paid,
                        color: color,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Settlement Section
                const Row(
                  children: [
                    Icon(Icons.handshake, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('Settlements & Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),

                if (split.isSettled)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 40),
                        SizedBox(height: 12),
                        Text(
                          'All Settled Up! 🎉',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'No pending dues in this group.',
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else
                  ...split.settlements.map((s) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.handshake_outlined, color: Colors.red, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.toString(),
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      _currencyFormat.format(s.amount),
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Action Buttons: Pay via UPI & WhatsApp Reminder
                          Row(
                            children: [
                              // Direct UPI Pay
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    foregroundColor: Colors.deepPurple,
                                    side: const BorderSide(color: Colors.deepPurple),
                                  ),
                                  onPressed: () {
                                    UpiWhatsAppService.payViaUpi(
                                      context: context,
                                      payeeName: s.to,
                                      amount: s.amount,
                                      note: 'SplitLedger: ${s.from} to ${s.to}',
                                    );
                                  },
                                  icon: const Icon(Icons.account_balance, size: 16),
                                  label: const Text('UPI Pay', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // WhatsApp Reminder
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    foregroundColor: const Color(0xFF25D366),
                                    side: const BorderSide(color: Color(0xFF25D366)),
                                  ),
                                  onPressed: () {
                                    UpiWhatsAppService.sendWhatsAppReminder(
                                      context: context,
                                      recipientName: s.from,
                                      amount: s.amount,
                                    );
                                  },
                                  icon: const Icon(Icons.chat, size: 16),
                                  label: const Text('WhatsApp', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Mark as Settled Button
                          if (household != null)
                            FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green.shade50,
                                foregroundColor: Colors.green.shade800,
                                side: BorderSide(color: Colors.green.shade200),
                              ),
                              onPressed: () => _recordSettlement(s, household.id, currentUser.uid, myName),
                              child: Text('Mark as Paid / Settle ${_currencyFormat.format(s.amount)}'),
                            ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 20),

                // Category Breakdown Card
                CategoryBreakdownCard(transactions: periodTransactions),
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
        padding: const EdgeInsets.all(14.0),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              _currencyFormat.format(amount),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
