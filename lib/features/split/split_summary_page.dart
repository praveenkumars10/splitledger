import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/date_filters.dart';
import '../../core/group_split_calculator.dart';
import '../../core/services/upi_whatsapp_service.dart';
import '../../models/transaction_model.dart';
import '../auth/auth_controller.dart';
import '../household/current_household_provider.dart';
import '../transactions/transaction_repository.dart';
import '../booklet/booklet_repository.dart';
import '../booklet/widgets/booklet_selector_bar.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/language_controller.dart';

class SplitSummaryPage extends ConsumerStatefulWidget {
  const SplitSummaryPage({super.key});

  @override
  ConsumerState<SplitSummaryPage> createState() => _SplitSummaryPageState();
}

class _SplitSummaryPageState extends ConsumerState<SplitSummaryPage> {
  bool _allTime = false;
  DateTime? _customRangeStart;
  DateTime? _customRangeEnd;

  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  Future<void> _selectCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _customRangeStart != null && _customRangeEnd != null
          ? DateTimeRange(start: _customRangeStart!, end: _customRangeEnd!)
          : DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
      helpText: 'Select Custom Split Date Range',
    );
    if (picked != null) {
      setState(() {
        _customRangeStart = picked.start;
        _customRangeEnd = picked.end;
        _allTime = false;
      });
    }
  }

  Future<void> _recordSettlement(SettlementTransaction s, String householdId, String currentUid, String currentName) async {
    final messenger = ScaffoldMessenger.of(context);
    final receiverUid = s.toUid.isNotEmpty ? s.toUid : currentUid;
    final receiverName = s.to.isNotEmpty ? s.to : currentName;
    final tx = TransactionModel(
      id: '',
      amount: s.amount,
      category: 'settlement',
      paidByUid: receiverUid,
      paidByName: receiverName,
      counterpartyUid: s.fromUid.isNotEmpty ? s.fromUid : null,
      note: 'Settlement: ${s.from} paid ${s.to}',
      date: DateTime.now(),
      type: TransactionType.received,
      createdAt: DateTime.now(),
      bookletId: ref.read(activeBookletProvider)?.id,
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
    final language = ref.watch(languageControllerProvider);
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    final activeBooklet = ref.watch(activeBookletProvider);
    final activeBookletTx = ref.watch(activeBookletTransactionsProvider);
    final isCustomActive = !_allTime && _customRangeStart != null && _customRangeEnd != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Text(AppStrings.tr(language, 'split_tab')),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: BookletSelectorBar(compact: true),
          ),
        ],
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (transactions) {
          if (currentUser == null) return const Center(child: Text('Not signed in'));

          final List<TransactionModel> periodTransactions;
          if (_allTime) {
            periodTransactions = transactions;
          } else if (isCustomActive) {
            periodTransactions = transactions
                .where((tx) => isInDateRange(tx.date, _customRangeStart!, _customRangeEnd!))
                .toList();
          } else {
            periodTransactions = activeBookletTx;
          }

          final groupMembers = household?.members.map((m) => (uid: m.uid, name: m.name)).toList() ?? [];
          final split = calculateGroupSplit(
            transactions: periodTransactions,
            members: groupMembers,
          );

          final myName = currentUser.displayName ?? AppStrings.tr(language, 'you');

          String activePeriodTitle;
          if (_allTime) {
            activePeriodTitle = AppStrings.tr(language, 'all_time');
          } else if (isCustomActive) {
            final sStr = DateFormat('d MMM').format(_customRangeStart!);
            final eStr = DateFormat('d MMM yyyy').format(_customRangeEnd!);
            activePeriodTitle = '$sStr – $eStr';
          } else {
            activePeriodTitle = activeBooklet?.name ?? AppStrings.tr(language, 'booklet');
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 90.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Period / Booklet selector
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Active Booklet Chip
                      ChoiceChip(
                        avatar: const Icon(Icons.menu_book_rounded, size: 16),
                        label: Text(activeBooklet?.name ?? AppStrings.tr(language, 'booklet')),
                        selected: !_allTime && !isCustomActive,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _allTime = false;
                              _customRangeStart = null;
                              _customRangeEnd = null;
                            });
                          } else {
                            showBookletSwitchSheet(context);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      // Custom date range chip / button
                      if (isCustomActive)
                        InputChip(
                          avatar: const Icon(Icons.date_range, size: 16),
                          label: Text(
                            '${DateFormat('d MMM').format(_customRangeStart!)} – ${DateFormat('d MMM').format(_customRangeEnd!)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          selected: true,
                          onDeleted: () {
                            setState(() {
                              _customRangeStart = null;
                              _customRangeEnd = null;
                            });
                          },
                          onPressed: _selectCustomDateRange,
                        )
                      else
                        ActionChip(
                          avatar: const Icon(Icons.date_range, size: 16),
                          label: Text(AppStrings.tr(language, 'custom_range')),
                          onPressed: _selectCustomDateRange,
                        ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(AppStrings.tr(language, 'all_time')),
                        selected: _allTime,
                        onSelected: (selected) {
                          setState(() {
                            _allTime = selected;
                            if (selected) {
                              _customRangeStart = null;
                              _customRangeEnd = null;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Total Expense Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          '${AppStrings.tr(language, 'total_group_expense')} ($activePeriodTitle)',
                          style: TextStyle(fontSize: 14, color: onSurfaceVariant),
                          textAlign: TextAlign.center,
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

                // Breakdown cards with LayoutBuilder
                if (split.balances.isNotEmpty)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = (constraints.maxWidth - 12) / 2;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: split.balances.map((b) {
                          final color = Colors.primaries[split.balances.indexOf(b) % Colors.primaries.length];
                          return SizedBox(
                            width: cardWidth,
                            child: _buildBreakdownCard(
                              title: '${b.name} ${AppStrings.tr(language, 'you_paid')}',
                              amount: b.paid,
                              color: color,
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                const SizedBox(height: 24),

                // Settlement Section
                Row(
                  children: [
                    Icon(Icons.handshake, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(AppStrings.tr(language, 'settlements'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                    child: Column(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          AppStrings.tr(language, 'no_due'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppStrings.tr(language, 'no_due_sub'),
                          style: TextStyle(fontSize: 13, color: onSurfaceVariant),
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
                                    foregroundColor: Theme.of(context).colorScheme.primary,
                                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
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
                                  label: Text(AppStrings.tr(language, 'pay_upi'), style: const TextStyle(fontSize: 12)),
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
                                  label: Text(AppStrings.tr(language, 'remind_whatsapp'), style: const TextStyle(fontSize: 12)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Mark as Settled Button
                          if (household != null)
                            FilledButton.tonal(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green.withValues(alpha: 0.15),
                                foregroundColor: Colors.green.shade800,
                                side: BorderSide(color: Colors.green.withValues(alpha: 0.3)),
                              ),
                              onPressed: () => _recordSettlement(s, household.id, currentUser.uid, myName),
                              child: Text('${AppStrings.tr(language, 'mark_paid')} ${_currencyFormat.format(s.amount)}'),
                            ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 20),
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
