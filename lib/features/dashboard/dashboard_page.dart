import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/date_filters.dart';
import '../../core/group_split_calculator.dart';
import '../../core/utils.dart';
import '../../models/transaction_model.dart';
import '../auth/auth_controller.dart';
import '../household/current_household_provider.dart';
import '../reports/reports_page.dart';
import '../settings/settings_page.dart';
import '../split/split_summary_page.dart';
import '../transactions/add_transaction_page.dart';
import '../transactions/transaction_repository.dart';
import '../wallet/wallet_repository.dart';
import '../../core/services/upi_whatsapp_service.dart';
import '../transactions/quick_add_bottom_sheet.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/language_controller.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  String _selectedTimeFilter = 'All';
  String _selectedUserFilter = 'all';
  DateTime _selectedMonth = DateTime.now();

  // Popup filter state
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  String? _keyword;
  double? _minAmount;
  double? _maxAmount;

  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9');
  final _monthFormat = DateFormat('MMM yyyy');
  final _dateFormat = DateFormat('dd MMM, hh:mm a');

  bool get _isMonthlyFilter => _selectedTimeFilter == 'Monthly';

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
      setState(() => _selectedMonth = DateTime(picked.year, picked.month));
    }
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final start = await showDatePicker(
      context: context,
      initialDate: _rangeStart ?? now.subtract(const Duration(days: 7)),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      helpText: 'Select start date',
    );
    if (start == null) return;
    if (!mounted) return;

    final end = await showDatePicker(
      context: context,
      initialDate: _rangeEnd ?? now,
      firstDate: start,
      lastDate: DateTime(now.year + 1),
      helpText: 'Select end date',
    );
    if (end == null) return;
    if (!mounted) return;

    setState(() {
      _rangeStart = start;
      _rangeEnd = end;
      _selectedTimeFilter = 'All';
    });
  }

  void _showKeywordSearch() {
    final controller = TextEditingController(text: _keyword ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Search notes, category or name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final query = controller.text.trim();
              Navigator.pop(context);
              if (mounted) {
                setState(() => _keyword = query.isEmpty ? null : query);
              }
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _showWalletDialog(double currentAmount, String uid) {
    final controller = TextEditingController(
      text: currentAmount > 0 ? currentAmount.toStringAsFixed(0) : '',
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Wallet Amount'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your total budget/cash balance:',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Wallet Amount',
                hintText: 'e.g. 2000 or 2k',
                prefixText: '\u20B9 ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // Quick preset chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [10, 20, 30, 50, 70, 100, 200, 500, 1000, 2000, 5000].map((preset) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ActionChip(
                      label: Text('₹$preset', style: const TextStyle(fontSize: 12)),
                      backgroundColor: Colors.deepPurple.shade50,
                      side: BorderSide(color: Colors.deepPurple.shade200),
                      onPressed: () {
                        controller.text = preset.toString();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final raw = controller.text.trim().toLowerCase();
              double? parsed;
              if (raw.endsWith('k')) {
                final numPart = double.tryParse(raw.replaceAll('k', '').trim());
                if (numPart != null) parsed = numPart * 1000;
              } else {
                parsed = double.tryParse(raw);
              }
              if (parsed != null && parsed >= 0) {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                try {
                  await ref.read(walletRepositoryProvider).setWalletAmount(uid, parsed);
                  messenger.showSnackBar(
                    SnackBar(content: Text('Wallet set to ${_currencyFormat.format(parsed)}')),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error saving wallet: $e')),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSettleUpDialog(GroupSplitResult split, String householdId, String currentUid, String currentName) {
    if (split.settlements.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('All Settled Up! 🎉'),
          content: const Text('There are no pending dues. Everyone is balanced.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.handshake_outlined, color: Colors.green),
            SizedBox(width: 8),
            Text('Settle Up'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pending settlements:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              ...split.settlements.map((s) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${s.from} owes ${s.to} ${_currencyFormat.format(s.amount)}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      // Action buttons: UPI Pay & WhatsApp Reminder
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                foregroundColor: Colors.deepPurple,
                                side: const BorderSide(color: Colors.deepPurple),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                UpiWhatsAppService.payViaUpi(
                                  context: context,
                                  payeeName: s.to,
                                  amount: s.amount,
                                  note: 'SplitLedger: ${s.from} to ${s.to}',
                                );
                              },
                              icon: const Icon(Icons.account_balance, size: 14),
                              label: const Text('UPI Pay', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                foregroundColor: const Color(0xFF25D366),
                                side: const BorderSide(color: Color(0xFF25D366)),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () {
                                UpiWhatsAppService.sendWhatsAppReminder(
                                  context: context,
                                  recipientName: s.from,
                                  amount: s.amount,
                                );
                              },
                              icon: const Icon(Icons.chat, size: 14),
                              label: const Text('WhatsApp', style: TextStyle(fontSize: 11)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.pop(context);
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
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          },
                          child: Text('Record ${_currencyFormat.format(s.amount)} Payment'),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _exportCsv(List<TransactionModel> transactions, String householdName) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('Date,Time,Description,Category,Paid By,Type,Amount (INR)');
      for (final tx in transactions) {
        final dateStr = DateFormat('yyyy-MM-dd').format(tx.date);
        final timeStr = DateFormat('hh:mm a').format(tx.date);
        final noteStr = (tx.note ?? '').replaceAll('"', '""');
        final categoryStr = tx.category.replaceAll('"', '""');
        final payerStr = tx.paidByName.replaceAll('"', '""');
        final typeStr = tx.type == TransactionType.paid ? 'Paid' : 'Received';
        final amountStr = tx.amount.toStringAsFixed(2);
        buffer.writeln('"$dateStr","$timeStr","$noteStr","$categoryStr","$payerStr","$typeStr",$amountStr');
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/SplitLedger_Transactions_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv');
      await file.writeAsString(buffer.toString());

      await SharePlus.instance.share(
        ShareParams(
          text: 'SplitLedger CSV Export for $householdName',
          files: [XFile(file.path)],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  void _showAmountFilter() {
    final minController = TextEditingController(
      text: _minAmount != null ? _minAmount!.toStringAsFixed(0) : '',
    );
    final maxController = TextEditingController(
      text: _maxAmount != null ? _maxAmount!.toStringAsFixed(0) : '',
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Amount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: minController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Minimum',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: maxController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Maximum',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _minAmount = null;
                _maxAmount = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              if (mounted) {
                setState(() {
                  _minAmount = double.tryParse(minController.text) ?? _minAmount;
                  _maxAmount = double.tryParse(maxController.text) ?? _maxAmount;
                  if (_minAmount != null && _maxAmount != null && _minAmount! > _maxAmount!) {
                    final temp = _minAmount;
                    _minAmount = _maxAmount;
                    _maxAmount = temp;
                  }
                });
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  void _shareSummary(GroupSplitResult split) {
    SharePlus.instance.share(
      ShareParams(
        text: 'SplitLedger Summary\n\n'
            'Total Expense: ${_currencyFormat.format(split.totalExpense)}\n'
            'Settlements:\n${split.settlements.isEmpty ? 'No due. All settled up!' : split.settlements.map((s) => s.toString()).join('\n')}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(currentTransactionsProvider);
    final household = ref.watch(currentHouseholdProvider).asData?.value;
    final currentUser = ref.watch(authStateChangesProvider).asData?.value;
    final walletAmount = ref.watch(currentWalletAmountProvider).asData?.value ?? 0.0;
    final language = ref.watch(languageControllerProvider);

    String partnerName = 'Partner';
    int totalMembers = 2;
    if (household != null && currentUser != null) {
      totalMembers = household.members.length;
      if (totalMembers > 2) {
        partnerName = 'Group';
      } else {
        final partner = household.members.where((m) => m.uid != currentUser.uid).firstOrNull;
        if (partner != null) partnerName = shortName(partner.name);
      }
    }

    final groupMembers = household?.members.map((m) => (uid: m.uid, name: shortName(m.name))).toList() ?? [];
    
    final allTransactions = transactionsAsync.whenOrNull(data: (value) => value) ?? [];
    final currentSplit = currentUser != null
        ? calculateGroupSplit(
            transactions: allTransactions,
            members: groupMembers,
          )
        : const GroupSplitResult(
            totalExpense: 0,
            memberCount: 0,
            individualShare: 0,
            balances: [],
            settlements: [],
          );

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.book, size: 48, color: Colors.white),
                  SizedBox(height: 8),
                  Text('SplitLedger', style: TextStyle(color: Colors.white, fontSize: 24)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet, color: Colors.deepPurple),
              title: const Text('Wallet'),
              subtitle: Text(
                walletAmount > 0
                    ? _currencyFormat.format(walletAmount)
                    : 'Tap to set initial amount (e.g. 2000)',
                style: TextStyle(
                  color: walletAmount > 0 ? Colors.black87 : Colors.grey,
                  fontWeight: walletAmount > 0 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: const Icon(Icons.edit, size: 20),
              onTap: () {
                Navigator.pop(context);
                if (currentUser != null) {
                  _showWalletDialog(walletAmount, currentUser.uid);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.handshake_outlined, color: Colors.green),
              title: const Text('Settle Up'),
              subtitle: Text(
                currentSplit.settlements.isEmpty
                    ? 'All settled up'
                    : '${currentSplit.settlements.length} dues pending',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                if (household != null && currentUser != null) {
                  _showSettleUpDialog(currentSplit, household.id, currentUser.uid, currentUser.displayName ?? 'You');
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.pie_chart),
              title: const Text('Split Summary'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SplitSummaryPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Export CSV / Excel'),
              onTap: () {
                Navigator.pop(context);
                _exportCsv(allTransactions, household?.name ?? 'Household');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share App'),
              onTap: () {
                Navigator.pop(context);
                SharePlus.instance.share(
                  ShareParams(
                    text: 'Check out SplitLedger — track and split household expenses easily!\n\nDownload the app here: https://play.google.com/store/apps/details?id=com.splitledger.split_ledger',
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context); // close drawer
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await ref.read(authControllerProvider).signOut();
                        },
                        child: const Text('Logout', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        title: Text(shortName(currentUser?.displayName ?? currentUser?.email ?? 'Dashboard')),
        actions: [
          IconButton(
            icon: const Icon(Icons.bolt, color: Colors.amberAccent),
            tooltip: '1-Tap Quick Expense',
            onPressed: () => QuickAddBottomSheet.show(context),
          ),
          PopupMenuButton<String>(
            tooltip: 'Filter Options',
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Icon(Icons.filter_list),
                  SizedBox(width: 8),
                  Text('Options'),
                ],
              ),
            ),
            onSelected: (value) {
              switch (value) {
                case 'Wallet':
                  if (currentUser != null) {
                    _showWalletDialog(walletAmount, currentUser.uid);
                  }
                  break;
                case 'Settle Up':
                  if (household != null && currentUser != null) {
                    _showSettleUpDialog(currentSplit, household.id, currentUser.uid, currentUser.displayName ?? 'You');
                  }
                  break;
                case 'Export CSV':
                  _exportCsv(allTransactions, household?.name ?? 'Household');
                  break;
                case 'Select Date Range':
                  _selectDateRange();
                  break;
                case 'Keyword Search':
                  _showKeywordSearch();
                  break;
                case 'Amount':
                  _showAmountFilter();
                  break;
                case 'Share':
                  _shareSummary(currentSplit);
                  break;
                case 'Report':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsPage()));
                  break;
                case 'Split Summary':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SplitSummaryPage()));
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Wallet', child: Row(children: [Icon(Icons.account_balance_wallet, size: 18), SizedBox(width: 8), Text('Wallet / Set Amount')])),
              const PopupMenuItem(value: 'Settle Up', child: Row(children: [Icon(Icons.handshake_outlined, size: 18, color: Colors.green), SizedBox(width: 8), Text('Settle Up')])),
              const PopupMenuItem(value: 'Export CSV', child: Row(children: [Icon(Icons.table_chart_outlined, size: 18), SizedBox(width: 8), Text('Export CSV / Excel')])),
              if (_rangeStart != null && _rangeEnd != null)
                PopupMenuItem(
                  value: 'Clear Range',
                  child: Text('Clear range (${DateFormat('dd MMM').format(_rangeStart!)} - ${DateFormat('dd MMM').format(_rangeEnd!)})'),
                  onTap: () => setState(() {
                    _rangeStart = null;
                    _rangeEnd = null;
                  }),
                ),
              const PopupMenuItem(value: 'Select Date Range', child: Text('Select Date Range')),
              const PopupMenuItem(value: 'Keyword Search', child: Text('Keyword Search')),
              const PopupMenuItem(value: 'Amount', child: Text('Amount')),
              const PopupMenuItem(value: 'Share', child: Text('Share')),
              const PopupMenuItem(value: 'Report', child: Text('Report')),
              const PopupMenuItem(value: 'Split Summary', child: Text('Split Summary')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(150),
          child: Column(
            children: [
              // Month selector row
              if (_isMonthlyFilter)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: Colors.white),
                        onPressed: () => setState(() {
                          _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                        }),
                      ),
                      TextButton(
                        onPressed: _selectMonth,
                        child: Text(
                          _monthFormat.format(_selectedMonth),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: Colors.white),
                        onPressed: () => setState(() {
                          _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                        }),
                      ),
                    ],
                  ),
                ),
              // Time filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: ['All', 'Daily', 'Weekly', 'Monthly', 'Yearly'].map((filter) {
                    final isSelected = _selectedTimeFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: InkWell(
                        onTap: () => setState(() {
                          _selectedTimeFilter = filter;
                          if (filter != 'Monthly') {
                            _selectedMonth = DateTime.now();
                          }
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white),
                          ),
                          child: Text(
                            filter,
                            style: TextStyle(
                              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              // User filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                child: Row(
                  children: (() {
                    final options = [
                      {'id': 'all', 'label': 'All'},
                      {'id': 'me', 'label': 'Me'},
                    ];
                    
                    if (household != null && currentUser != null) {
                      if (household.members.length > 4) {
                        options.add({'id': 'group', 'label': "Groups"});
                      } else if (household.members.length == 2) {
                        final partner = household.members.firstWhere((m) => m.uid != currentUser.uid);
                        options.add({'id': 'group', 'label': shortName(partner.name)});
                      } else {
                        for (var m in household.members) {
                          if (m.uid != currentUser.uid) {
                            options.add({'id': m.uid, 'label': shortName(m.name)});
                          }
                        }
                      }
                    } else {
                       options.add({'id': 'group', 'label': "Partner"});
                    }

                    return options.map((option) {
                      final isSelected = _selectedUserFilter == option['id'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                        child: InkWell(
                          onTap: () => setState(() => _selectedUserFilter = option['id']!),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white),
                            ),
                            child: Text(
                              option['label']!,
                              style: TextStyle(
                                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList();
                  })(),
                ),
              ),
            ],
          ),
        ),
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (transactions) {
          if (currentUser == null) return const Center(child: Text('Not signed in'));

          final filtered = filterTransactions(
            transactions,
            timeFilter: _selectedTimeFilter,
            userFilter: _selectedUserFilter,
            currentUserId: currentUser.uid,
            selectedMonth: _selectedMonth,
            rangeStart: _rangeStart,
            rangeEnd: _rangeEnd,
            keyword: _keyword,
            minAmount: _minAmount,
            maxAmount: _maxAmount,
          );

          final settlementTransactions = filterTransactions(
            transactions,
            timeFilter: _selectedTimeFilter,
            userFilter: 'all',
            currentUserId: currentUser.uid,
            selectedMonth: _selectedMonth,
            rangeStart: _rangeStart,
            rangeEnd: _rangeEnd,
          );
          final periodSplit = calculateGroupSplit(
            transactions: settlementTransactions,
            members: groupMembers,
          );
          
          final myBalance = periodSplit.balances.firstWhere(
            (b) => b.uid == currentUser.uid,
            orElse: () => const MemberBalance(uid: '', name: 'You', paid: 0, share: 0),
          );
          final net = myBalance.net;

          double totalReceived = 0;
          double totalPaid = 0;
          for (final tx in filtered) {
            if (tx.type == TransactionType.paid) {
              totalPaid += tx.amount;
            } else {
              totalReceived += tx.amount;
            }
          }

          // Balance calculation based on Wallet
          final double remainingBalance;
          final String balanceSubtext;
          final Color balanceColor;

          if (walletAmount > 0) {
            remainingBalance = walletAmount - totalPaid + totalReceived;
            balanceSubtext = 'Remaining';
            balanceColor = remainingBalance >= 0 ? Colors.green.shade700 : Colors.red.shade700;
          } else {
            remainingBalance = net;
            balanceSubtext = net.abs() < 0.01 ? 'No due' : (net > 0 ? '(Get)' : '(Owe)');
            balanceColor = net > 0 ? Colors.green.shade700 : (net < -0.01 ? Colors.red.shade700 : Colors.grey.shade700);
          }

          return Column(
            children: [
              // Active filter chips
              if (_keyword != null || _rangeStart != null || _minAmount != null)
                Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (_keyword != null)
                        _buildFilterChip('Search: $_keyword', () => setState(() => _keyword = null)),
                      if (_rangeStart != null && _rangeEnd != null)
                        _buildFilterChip(
                          '${DateFormat('dd MMM').format(_rangeStart!)} - ${DateFormat('dd MMM').format(_rangeEnd!)}',
                          () => setState(() {
                            _rangeStart = null;
                            _rangeEnd = null;
                          }),
                        ),
                      if (_minAmount != null || _maxAmount != null)
                        _buildFilterChip(
                          '${_minAmount != null ? _currencyFormat.format(_minAmount) : '0'} - ${_maxAmount != null ? _currencyFormat.format(_maxAmount) : 'Any'}',
                          () => setState(() {
                            _minAmount = null;
                            _maxAmount = null;
                          }),
                        ),
                    ],
                  ),
                ),
              // Header Row
              Container(
                color: Theme.of(context).colorScheme.primaryContainer,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: const Row(
                  children: [
                    Expanded(flex: 4, child: Text('Notes', style: TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 3, child: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                    Expanded(flex: 2, child: Text('By', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                  ],
                ),
              ),
              // List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey.shade400),
                            const SizedBox(height: 8),
                            const Text('No transactions match the filters.', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final tx = filtered[index];
                          final isMe = tx.paidByUid == currentUser.uid;
                          final isPaid = tx.type == TransactionType.paid;
                          final color = isPaid ? Colors.red.shade700 : Colors.green.shade700;
                          final titleText = (tx.note != null && tx.note!.trim().isNotEmpty)
                              ? tx.note!.trim()
                              : (tx.category.isNotEmpty ? tx.category : 'General');

                          return Dismissible(
                            key: ValueKey(tx.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.red.shade600,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Icon(Icons.delete, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            confirmDismiss: (_) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete transaction?'),
                                  content: Text('Are you sure you want to delete this ${_currencyFormat.format(tx.amount)} transaction?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
                            child: InkWell(
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
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // 1. Notes & Date with Emoji
                                    Expanded(
                                      flex: 4,
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 34,
                                            height: 34,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: color.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(getCategoryEmoji(titleText), style: const TextStyle(fontSize: 16)),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  titleText,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.black87,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _dateFormat.format(tx.date),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // 2. Amount
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        _currencyFormat.format(tx.amount),
                                        style: TextStyle(
                                          color: color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    // 3. By
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        isMe ? 'You' : partnerName,
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isMe ? FontWeight.w600 : FontWeight.normal,
                                          color: isMe ? Theme.of(context).colorScheme.primary : Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              // Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTransactionPage(type: TransactionType.received)));
                        },
                        child: Text(
                          AppStrings.tr(language, 'you_received'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Quick Add Center Button
                    InkWell(
                      onTap: () => QuickAddBottomSheet.show(context),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade700,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bolt, color: Colors.white, size: 16),
                            const SizedBox(width: 2),
                            Text(
                              AppStrings.tr(language, 'quick_expense'),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTransactionPage(type: TransactionType.paid)));
                        },
                        child: Text(
                          AppStrings.tr(language, 'you_paid'),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Footer
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade300)),
                  color: Theme.of(context).colorScheme.surface,
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      // 1. Wallet column
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            _showWalletDialog(walletAmount, currentUser.uid);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      AppStrings.tr(language, 'wallet'),
                                      style: const TextStyle(
                                        color: Colors.deepPurple,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(Icons.edit, size: 11, color: Colors.deepPurple.shade400),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  walletAmount > 0 ? _currencyFormat.format(walletAmount) : 'Set \u20B9',
                                  style: TextStyle(
                                    color: walletAmount > 0 ? Colors.deepPurple.shade700 : Colors.deepPurple.shade300,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      VerticalDivider(color: Colors.grey.shade300, width: 1),
                      // 2. Total Received
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(AppStrings.tr(language, 'total_received'), style: const TextStyle(color: Colors.green, fontSize: 10), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(
                                _currencyFormat.format(totalReceived),
                                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      VerticalDivider(color: Colors.grey.shade300, width: 1),
                      // 3. Total Paid
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(AppStrings.tr(language, 'total_paid'), style: const TextStyle(color: Colors.red, fontSize: 10), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(
                                _currencyFormat.format(totalPaid),
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      VerticalDivider(color: Colors.grey.shade300, width: 1),
                      // 4. Your Balance (Remaining)
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            if (walletAmount <= 0) {
                              _showWalletDialog(walletAmount, currentUser.uid);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(AppStrings.tr(language, 'your_balance'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 2),
                                Text(
                                  walletAmount > 0
                                      ? _currencyFormat.format(remainingBalance)
                                      : (net.abs() < 0.01 ? 'No due' : '\u20B9${net.abs().toStringAsFixed(0)}'),
                                  style: TextStyle(
                                    color: balanceColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  balanceSubtext,
                                  style: TextStyle(
                                    color: balanceColor,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return InputChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onDeleted: onRemove,
      deleteIcon: const Icon(Icons.close, size: 18),
      visualDensity: VisualDensity.compact,
    );
  }
}
