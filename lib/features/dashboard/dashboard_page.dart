import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/date_filters.dart';
import '../../core/group_split_calculator.dart';
import '../../core/utils.dart';
import '../../models/transaction_model.dart';
import '../auth/auth_controller.dart';
import '../household/current_household_provider.dart';
import '../settings/settings_page.dart';
import '../transactions/add_transaction_page.dart';
import '../transactions/transaction_repository.dart';
import '../wallet/wallet_repository.dart';
import '../transactions/quick_add_bottom_sheet.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/language_controller.dart';
import '../../core/preferences/app_preferences.dart';

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

  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final _monthFormat = DateFormat('MMM yyyy');
  final _dateFormat = DateFormat('dd MMM, hh:mm a');

  bool get _isMonthlyFilter => _selectedTimeFilter == 'Monthly';
  bool get _hasActiveFilters => _keyword != null || _rangeStart != null || _minAmount != null || _maxAmount != null;

  void _clearAllFilters() {
    setState(() {
      _keyword = null;
      _rangeStart = null;
      _rangeEnd = null;
      _minAmount = null;
      _maxAmount = null;
    });
  }

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
    final language = ref.read(languageControllerProvider);
    final controller = TextEditingController(text: _keyword ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.tr(language, 'search_title')),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: AppStrings.tr(language, 'search_hint'),
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppStrings.tr(language, 'cancel')),
          ),
          FilledButton(
            onPressed: () {
              final query = controller.text.trim();
              Navigator.pop(context);
              if (mounted) {
                setState(() => _keyword = query.isEmpty ? null : query);
              }
            },
            child: Text(AppStrings.tr(language, 'search_title')),
          ),
        ],
      ),
    );
  }

  void _showWalletDialog(double currentAmount, String uid) {
    final language = ref.read(languageControllerProvider);
    final controller = TextEditingController(
      text: currentAmount > 0 ? currentAmount.toStringAsFixed(0) : '',
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(AppStrings.tr(language, 'wallet_amount')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.tr(language, 'wallet_desc'),
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                labelText: AppStrings.tr(language, 'wallet_amount'),
                hintText: 'e.g. 2000 or 2k',
                prefixText: '₹ ',
                border: const OutlineInputBorder(),
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
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
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
            child: Text(AppStrings.tr(language, 'cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final raw = controller.text.trim().toLowerCase();
              double? parsed;
              if (raw.endsWith('k')) {
                final numPart = double.tryParse(raw.replaceAll('k', '').trim());
                if (numPart != null) parsed = numPart * 1000;
              } else {
                final clean = raw.replaceAll(',', '').trim();
                parsed = double.tryParse(clean);
              }
              if (parsed != null && parsed >= 0) {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                try {
                  await ref.read(walletRepositoryProvider).setWalletAmount(uid, parsed);
                  messenger.showSnackBar(
                    SnackBar(content: Text('${AppStrings.tr(language, 'wallet')}: ${_currencyFormat.format(parsed)}')),
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
            child: Text(AppStrings.tr(language, 'save')),
          ),
        ],
      ),
    );
  }

  void _showAmountFilter() {
    final language = ref.read(languageControllerProvider);
    final minController = TextEditingController(
      text: _minAmount != null ? _minAmount!.toStringAsFixed(0) : '',
    );
    final maxController = TextEditingController(
      text: _maxAmount != null ? _maxAmount!.toStringAsFixed(0) : '',
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.tr(language, 'filter_by_amount')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: minController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: AppStrings.tr(language, 'min_amount'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: maxController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: AppStrings.tr(language, 'max_amount'),
                border: const OutlineInputBorder(),
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
            child: Text(AppStrings.tr(language, 'clear_filter')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _minAmount = double.tryParse(minController.text.trim());
                _maxAmount = double.tryParse(maxController.text.trim());
              });
            },
            child: Text(AppStrings.tr(language, 'apply_filter')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final household = ref.watch(currentHouseholdProvider).asData?.value;
    final currentUser = ref.watch(authStateChangesProvider).asData?.value;
    final walletAmount = ref.watch(currentWalletAmountProvider).asData?.value ?? 0.0;
    final transactionsAsync = ref.watch(currentTransactionsProvider);
    final language = ref.watch(languageControllerProvider);
    final preferences = ref.watch(appPreferencesProvider);
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    String partnerName = 'Partner';
    if (household != null && currentUser != null) {
      final partner = household.members.where((m) => m.uid != currentUser.uid).firstOrNull;
      if (partner != null) {
        partnerName = shortName(partner.name);
      }
    }

    final groupMembers = household?.members.map((m) => (uid: m.uid, name: shortName(m.name))).toList() ?? [];

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
                  Text('SplitLedger', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ListTile(
              leading: Icon(Icons.account_balance_wallet, color: Theme.of(context).colorScheme.primary),
              title: Text(AppStrings.tr(language, 'wallet')),
              subtitle: Text(
                walletAmount > 0
                    ? _currencyFormat.format(walletAmount)
                    : AppStrings.tr(language, 'wallet_not_set'),
                style: TextStyle(
                  color: walletAmount > 0 ? Theme.of(context).colorScheme.onSurface : onSurfaceVariant,
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
              leading: const Icon(Icons.settings),
              title: Text(AppStrings.tr(language, 'settings_tab')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: Text(AppStrings.tr(language, 'share_app')),
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
              title: Text(AppStrings.tr(language, 'logout'), style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context); // close drawer
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(AppStrings.tr(language, 'logout')),
                    content: Text(AppStrings.tr(language, 'logout_confirm')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(AppStrings.tr(language, 'cancel')),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await ref.read(authControllerProvider).signOut();
                        },
                        child: Text(AppStrings.tr(language, 'logout'), style: const TextStyle(color: Colors.red)),
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
            icon: Icon(
              preferences.isPrivacyMode ? Icons.visibility_off : Icons.visibility,
              color: Colors.white,
            ),
            tooltip: preferences.isPrivacyMode ? 'Show Balances' : 'Hide Balances (Privacy)',
            onPressed: () => ref.read(appPreferencesProvider.notifier).togglePrivacyMode(),
          ),
          IconButton(
            icon: const Icon(Icons.bolt, color: Colors.amberAccent),
            tooltip: '1-Tap Quick Expense',
            onPressed: () => QuickAddBottomSheet.show(context),
          ),
          PopupMenuButton<String>(
            tooltip: AppStrings.tr(language, 'filter_options'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Row(
                children: [
                  const Icon(Icons.filter_list),
                  const SizedBox(width: 4),
                  Text(AppStrings.tr(language, 'filter_options')),
                ],
              ),
            ),
            onSelected: (value) {
              switch (value) {
                case 'Search':
                  _showKeywordSearch();
                  break;
                case 'DateRange':
                  _selectDateRange();
                  break;
                case 'Amount':
                  _showAmountFilter();
                  break;
                case 'Clear':
                  _clearAllFilters();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'Search',
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 18),
                    const SizedBox(width: 8),
                    Text(AppStrings.tr(language, 'search_title')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'DateRange',
                child: Row(
                  children: [
                    const Icon(Icons.date_range, size: 18),
                    const SizedBox(width: 8),
                    const Text('Select Date Range'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'Amount',
                child: Row(
                  children: [
                    const Icon(Icons.tune, size: 18),
                    const SizedBox(width: 8),
                    Text(AppStrings.tr(language, 'filter_by_amount')),
                  ],
                ),
              ),
              if (_hasActiveFilters) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'Clear',
                  child: Row(
                    children: [
                      const Icon(Icons.clear_all, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(AppStrings.tr(language, 'clear_filter'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_isMonthlyFilter ? 145 : 95),
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
                  children: [
                    ('All', AppStrings.tr(language, 'all_time')),
                    ('Daily', AppStrings.tr(language, 'daily')),
                    ('Weekly', AppStrings.tr(language, 'weekly')),
                    ('Monthly', AppStrings.tr(language, 'monthly')),
                    ('Yearly', AppStrings.tr(language, 'yearly')),
                  ].map((filterItem) {
                    final filterKey = filterItem.$1;
                    final filterLabel = filterItem.$2;
                    final isSelected = _selectedTimeFilter == filterKey;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: InkWell(
                        onTap: () => setState(() {
                          _selectedTimeFilter = filterKey;
                          if (filterKey != 'Monthly') {
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
                            filterLabel,
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
                      {'id': 'all', 'label': AppStrings.tr(language, 'all_time')},
                      {'id': 'me', 'label': AppStrings.tr(language, 'you')},
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
                       options.add({'id': 'group', 'label': partnerName});
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
            balanceSubtext = AppStrings.tr(language, 'your_balance');
            balanceColor = remainingBalance >= 0 ? Colors.green.shade700 : Colors.red.shade700;
          } else {
            remainingBalance = net;
            balanceSubtext = net.abs() < 0.01 ? AppStrings.tr(language, 'no_due') : (net > 0 ? '(Get)' : '(Owe)');
            balanceColor = net > 0 ? Colors.green.shade700 : (net < -0.01 ? Colors.red.shade700 : onSurfaceVariant);
          }

          return Column(
            children: [
              // Active filter chips
              if (_hasActiveFilters)
                Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (_keyword != null)
                        _buildFilterChip('${AppStrings.tr(language, 'search_title')}: $_keyword', () => setState(() => _keyword = null)),
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
                      ActionChip(
                        avatar: const Icon(Icons.clear_all, size: 16, color: Colors.red),
                        label: Text(AppStrings.tr(language, 'clear_filter'), style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: _clearAllFilters,
                      ),
                    ],
                  ),
                ),
              // Header Row
              Container(
                color: Theme.of(context).colorScheme.primaryContainer,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  children: [
                    Expanded(flex: 4, child: Text(AppStrings.tr(language, 'notes_category_header'), style: const TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 3, child: Text(AppStrings.tr(language, 'amount_header'), style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
                    Expanded(flex: 2, child: Text(AppStrings.tr(language, 'by_header'), style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
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
                            Icon(Icons.receipt_long_outlined, size: 56, color: onSurfaceVariant.withValues(alpha: 0.5)),
                            const SizedBox(height: 8),
                            Text(AppStrings.tr(language, 'no_matching_tx'), style: TextStyle(color: onSurfaceVariant)),
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
                              : (tx.category.isNotEmpty ? tx.category : AppStrings.tr(language, 'other'));

                          return Dismissible(
                            key: ValueKey(tx.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.red.shade600,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Icon(Icons.delete, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(AppStrings.tr(language, 'delete'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            confirmDismiss: (_) async {
                              return await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(AppStrings.tr(language, 'delete_tx_title')),
                                  content: Text('${AppStrings.tr(language, 'delete_tx_confirm')}\n"${_currencyFormat.format(tx.amount)}" ($titleText)'),
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
                            },
                            onDismissed: (_) async {
                              if (household == null) return;
                              try {
                                await ref.read(transactionRepositoryProvider).deleteTransaction(household.id, tx.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(AppStrings.tr(language, 'tx_deleted'))),
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
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Theme.of(context).colorScheme.onSurface,
                                                  ),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _dateFormat.format(tx.date),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: onSurfaceVariant,
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
                                        isMe ? AppStrings.tr(language, 'you') : partnerName,
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isMe ? FontWeight.w600 : FontWeight.normal,
                                          color: isMe ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
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
              // Footer
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
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
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        AppStrings.tr(language, 'wallet'),
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(Icons.edit, size: 11, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    preferences.isPrivacyMode
                                        ? '₹••••'
                                        : (walletAmount > 0 ? _currencyFormat.format(walletAmount) : 'Set ₹'),
                                    style: TextStyle(
                                      color: walletAmount > 0 ? Theme.of(context).colorScheme.primary : onSurfaceVariant,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      VerticalDivider(color: Theme.of(context).dividerColor, width: 1),
                      // 2. Total Received
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  AppStrings.tr(language, 'total_received'),
                                  style: const TextStyle(color: Colors.green, fontSize: 10),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  preferences.isPrivacyMode ? '₹••••' : _currencyFormat.format(totalReceived),
                                  style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      VerticalDivider(color: Theme.of(context).dividerColor, width: 1),
                      // 3. Total Paid
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  AppStrings.tr(language, 'total_paid'),
                                  style: const TextStyle(color: Colors.red, fontSize: 10),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  preferences.isPrivacyMode ? '₹••••' : _currencyFormat.format(totalPaid),
                                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      VerticalDivider(color: Theme.of(context).dividerColor, width: 1),
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
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    AppStrings.tr(language, 'your_balance'),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    preferences.isPrivacyMode
                                        ? '₹••••'
                                        : (walletAmount > 0
                                            ? _currencyFormat.format(remainingBalance)
                                            : (net.abs() < 0.01 ? AppStrings.tr(language, 'no_due') : '₹${net.abs().toStringAsFixed(0)}')),
                                    style: TextStyle(
                                      color: balanceColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    balanceSubtext,
                                    style: TextStyle(
                                      color: balanceColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
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
