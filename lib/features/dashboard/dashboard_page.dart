import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/date_filters.dart';
import '../../core/group_split_calculator.dart';
import '../../core/utils.dart';
import '../../models/transaction_model.dart';
import '../../models/booklet_model.dart';
import '../../models/household_model.dart';
import '../auth/auth_controller.dart';
import '../household/current_household_provider.dart';
import '../settings/settings_page.dart';
import '../transactions/add_transaction_page.dart';
import '../transactions/transaction_repository.dart';
import '../wallet/wallet_repository.dart';
import '../booklet/booklet_repository.dart';
import '../booklet/widgets/booklet_selector_bar.dart';
import '../transactions/quick_add_bottom_sheet.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/language_controller.dart';
import '../../core/preferences/app_preferences.dart';
import '../budget/widgets/budget_alert_card.dart';
import '../budget/widgets/category_budget_dialog.dart';
import '../recurring/recurring_page.dart';
import '../savings/savings_page.dart';
import '../history/deleted_history_page.dart';
import '../transactions/transaction_history_page.dart';
import '../../core/widgets/receipt_viewer_dialog.dart';

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
  bool _isAutoConsolidating = false;

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

  void _showKeywordSearch() async {
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => _DashboardKeywordSearchDialog(
        initialKeyword: _keyword ?? '',
      ),
    );
    if (result != null && mounted) {
      setState(() => _keyword = result.isEmpty ? null : result);
    }
  }

  void _showWalletDialog({
    required double currentAmount,
    required String uid,
    required BookletModel? activeBooklet,
    required String selectedUserFilter,
  }) {
    showDialog(
      context: context,
      builder: (context) => _DashboardWalletDialog(
        currentAmount: currentAmount,
        uid: uid,
        activeBooklet: activeBooklet,
        selectedUserFilter: selectedUserFilter,
        householdId: ref.read(currentHouseholdProvider).asData?.value?.id,
      ),
    );
  }

  void _showAmountFilter() async {
    final result = await showDialog<Map<String, double?>?>(
      context: context,
      builder: (context) => _DashboardAmountFilterDialog(
        minAmount: _minAmount,
        maxAmount: _maxAmount,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _minAmount = result['min'];
        _maxAmount = result['max'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final household = ref.watch(currentHouseholdProvider).asData?.value;
    final currentUser = ref.watch(authStateChangesProvider).asData?.value;
    final activeBooklet = ref.watch(activeBookletProvider);
    final userBookletWallets = ref.watch(userBookletWalletsProvider).asData?.value ?? {};
    final transactionsAsync = ref.watch(currentTransactionsProvider);
    final language = ref.watch(languageControllerProvider);
    final preferences = ref.watch(appPreferencesProvider);
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    String partnerName = 'Partner';
    HouseholdMember? partner;
    if (household != null && currentUser != null) {
      partner = household.members.where((m) => m.uid != currentUser.uid).firstOrNull;
      if (partner != null) {
        partnerName = shortName(partner.name);
      }
    }

    final groupMembers = household?.members.map((m) => (uid: m.uid, name: shortName(m.name))).toList() ?? [];

    if (!_isAutoConsolidating && household != null && currentUser != null) {
      final allTx = ref.watch(currentTransactionsProvider).asData?.value;
      if (allTx != null && allTx.isNotEmpty) {
        final booklets = ref.watch(bookletsStreamProvider).asData?.value ?? [];

        // 1. If no booklets exist in Firestore, create the initial Main Cashbook and transfer all transactions into it
        if (booklets.isEmpty) {
          _isAutoConsolidating = true;
          Future.microtask(() async {
            try {
              final newBooklet = await ref.read(bookletRepositoryProvider).createBooklet(
                    householdId: household.id,
                    name: 'Main Cashbook',
                    startDate: household.createdAt,
                    createdByUid: currentUser.uid,
                    createdByName: currentUser.displayName ?? 'User',
                  );
              await ref.read(bookletRepositoryProvider).transferAllTransactionsToBooklet(
                    householdId: household.id,
                    targetBookletId: newBooklet.id,
                  );
              ref.read(selectedBookletFilterProvider.notifier).setFilter(newBooklet.id);
              await ref.read(appPreferencesProvider.notifier).setActiveBookletId(newBooklet.id);
            } catch (_) {
            } finally {
              if (mounted) _isAutoConsolidating = false;
            }
          });
        } else if (activeBooklet != null && activeBooklet.id != 'default') {
          // 2. Ensure existing wallet amounts have an incoming transaction (Bank passbook credit entry)
          final hasMissingWalletTx = activeBooklet.memberWallets.entries.any((entry) {
            final uid = entry.key;
            final amt = entry.value;
            if (amt <= 0) return false;
            return !allTx.any((tx) =>
                tx.bookletId == activeBooklet.id &&
                tx.paidByUid == uid &&
                tx.type == TransactionType.received &&
                tx.category.toLowerCase() == 'wallet');
          });

          // Check if duplicate wallet transactions exist that need Firestore cleanup
          final hasDuplicateWalletTx = () {
            final seen = <String>{};
            for (final tx in allTx) {
              if (tx.bookletId == activeBooklet.id && tx.category.toLowerCase() == 'wallet') {
                if (!seen.add(tx.paidByUid)) return true;
              }
            }
            return false;
          }();

          if ((hasMissingWalletTx || hasDuplicateWalletTx) && !_isAutoConsolidating) {
            _isAutoConsolidating = true;
            Future.microtask(() async {
              try {
                for (final entry in activeBooklet.memberWallets.entries) {
                  final uid = entry.key;
                  final amt = entry.value;
                  final memberName = household.members.where((m) => m.uid == uid).firstOrNull?.name ?? 'Member';
                  await ref.read(walletRepositoryProvider).ensureWalletTransaction(
                        householdId: household.id,
                        bookletId: activeBooklet.id,
                        uid: uid,
                        amount: amt,
                        userName: memberName,
                      );
                }
              } catch (_) {
              } finally {
                if (mounted) _isAutoConsolidating = false;
              }
            });
          }
        }
      }
    }

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.book_rounded, size: 28, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SplitLedger', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                          Text('Smart Cashbook & Ledger', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (household != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.home_outlined, size: 14, color: Colors.white70),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            household.name,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    currentUser?.email ?? currentUser?.displayName ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Core Cashbooks & Wallets
            ListTile(
              leading: Icon(Icons.menu_book_rounded, color: Theme.of(context).colorScheme.primary),
              title: Text(AppStrings.tr(language, 'switch_booklet')),
              subtitle: Text(
                activeBooklet?.name ?? 'Main Cashbook',
                style: TextStyle(fontSize: 12, color: onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                Navigator.pop(context);
                showBookletSwitchSheet(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.account_balance_wallet, color: Theme.of(context).colorScheme.primary),
              title: Text(AppStrings.tr(language, 'wallet')),
              subtitle: Text(
                (activeBooklet?.getMemberWallet(currentUser?.uid ?? '', userBookletWallets: userBookletWallets) ?? 0) > 0
                    ? '${activeBooklet!.name}: ${_currencyFormat.format(activeBooklet.getMemberWallet(currentUser?.uid ?? '', userBookletWallets: userBookletWallets))}'
                    : '${activeBooklet?.name ?? 'Wallet'}: ${AppStrings.tr(language, 'wallet_not_set')}',
                style: TextStyle(
                  color: (activeBooklet?.getMemberWallet(currentUser?.uid ?? '', userBookletWallets: userBookletWallets) ?? 0) > 0
                      ? Theme.of(context).colorScheme.onSurface
                      : onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.edit, size: 18),
              onTap: () {
                Navigator.pop(context);
                if (currentUser != null) {
                  final initialAmt = activeBooklet?.getMemberWallet(currentUser.uid, userBookletWallets: userBookletWallets) ?? 0.0;
                  _showWalletDialog(
                    currentAmount: initialAmt,
                    uid: currentUser.uid,
                    activeBooklet: activeBooklet,
                    selectedUserFilter: _selectedUserFilter,
                  );
                }
              },
            ),
            const Divider(),
            // History Options
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long, color: Colors.blue, size: 20),
              ),
              title: Text(AppStrings.tr(language, 'menu_history'), style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(AppStrings.tr(language, 'history_tab'), style: TextStyle(fontSize: 11, color: onSurfaceVariant)),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionHistoryPage()));
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.history_toggle_off_rounded, color: Colors.redAccent, size: 20),
              ),
              title: Text(AppStrings.tr(language, 'deleted_history'), style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(AppStrings.tr(language, 'deleted_history_desc'), style: TextStyle(fontSize: 11, color: onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DeletedHistoryPage()));
              },
            ),
            const Divider(),
            // Budgets & Goals
            ListTile(
              leading: Icon(Icons.tune_rounded, color: Theme.of(context).colorScheme.primary),
              title: Text(AppStrings.tr(language, 'category_budgets')),
              subtitle: Text(AppStrings.tr(language, 'category_budgets_desc'), style: TextStyle(fontSize: 11, color: onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.pop(context);
                CategoryBudgetDialog.show(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.autorenew, color: Theme.of(context).colorScheme.primary),
              title: Text(AppStrings.tr(language, 'recurring_expenses')),
              subtitle: Text(AppStrings.tr(language, 'recurring_desc'), style: TextStyle(fontSize: 11, color: onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const RecurringPage()));
              },
            ),
            ListTile(
              leading: Icon(Icons.savings_outlined, color: Theme.of(context).colorScheme.primary),
              title: Text(AppStrings.tr(language, 'savings_goals')),
              subtitle: Text(AppStrings.tr(language, 'savings_desc'), style: TextStyle(fontSize: 11, color: onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SavingsPage()));
              },
            ),
            const Divider(),
            // Settings & Share
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(AppStrings.tr(language, 'settings_tab')),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
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
              title: Text(AppStrings.tr(language, 'logout'), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: BookletSelectorBar(compact: true),
          ),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
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
                case 'History':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionHistoryPage()));
                  break;
                case 'DeletedHistory':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DeletedHistoryPage()));
                  break;
                case 'Booklet':
                  showBookletSwitchSheet(context);
                  break;
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
            itemBuilder: (context) {
              final colorScheme = Theme.of(context).colorScheme;
              return [
                PopupMenuItem(
                  value: 'History',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.receipt_long, size: 18, color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppStrings.tr(language, 'menu_history'),
                        style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'DeletedHistory',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.history_toggle_off_rounded, size: 18, color: Colors.redAccent),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppStrings.tr(language, 'deleted_history'),
                        style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'Booklet',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.menu_book_rounded, size: 18, color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppStrings.tr(language, 'switch_booklet'),
                        style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'Search',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.search, size: 18, color: Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppStrings.tr(language, 'search_title'),
                        style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'DateRange',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.date_range, size: 18, color: Colors.purple),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppStrings.tr(language, 'select_date_range'),
                        style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'Amount',
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.tune, size: 18, color: Colors.orange),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppStrings.tr(language, 'filter_by_amount'),
                        style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                if (_hasActiveFilters) ...[
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'Clear',
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.clear_all, size: 18, color: Colors.red),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          AppStrings.tr(language, 'clear_filter'),
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ];
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_isMonthlyFilter ? 145 : 95),
          child: Column(
            children: [
              // Month selector row
              if (_isMonthlyFilter) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: Colors.white),
                        tooltip: 'Previous month',
                        onPressed: () => setState(() {
                          _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                        }),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_month, color: Colors.white, size: 16),
                        onPressed: _selectMonth,
                        label: Text(
                          _monthFormat.format(_selectedMonth),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: Colors.white),
                        tooltip: 'Next month',
                        onPressed: () => setState(() {
                          _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                        }),
                      ),
                    ],
                  ),
                ),
              ],

              // Time filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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

          final activeBookletTransactions = ref.watch(activeBookletTransactionsProvider);

          final filtered = filterTransactions(
            activeBookletTransactions,
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
            activeBookletTransactions,
            timeFilter: _selectedTimeFilter,
            userFilter: 'all',
            currentUserId: currentUser.uid,
            selectedMonth: _selectedMonth,
            rangeStart: _rangeStart,
            rangeEnd: _rangeEnd,
          ).where((t) => t.category.toLowerCase() != 'wallet').toList();
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

          // -------------------------------------------------------------
          // Dynamic Wallet & Balance calculations for Cashbook & Users
          // -------------------------------------------------------------
          final bool isAllUsers = _selectedUserFilter == 'all';
          final double displayedWalletAmount;
          final String walletCardTitle;

          if (activeBooklet != null) {
            // SPECIFIC BOOKLET SELECTED: Read ONLY this booklet's wallets
            if (isAllUsers) {
              displayedWalletAmount = activeBooklet.getTotalWalletAmount(
                userBookletWallets: userBookletWallets,
                currentUid: currentUser.uid,
              );
              walletCardTitle = AppStrings.tr(language, 'total_wallet');
            } else if (_selectedUserFilter == 'me') {
              displayedWalletAmount = activeBooklet.getMemberWallet(
                currentUser.uid,
                userBookletWallets: userBookletWallets,
              );
              walletCardTitle = AppStrings.tr(language, 'your_wallet');
            } else if (_selectedUserFilter == 'group' && partner != null) {
              displayedWalletAmount = activeBooklet.getMemberWallet(
                partner.uid,
                userBookletWallets: userBookletWallets,
              );
              final rawName = shortName(partner.name);
              walletCardTitle = rawName.length <= 7
                  ? (language == AppLanguage.tamil ? '$rawName வாலட்' : "$rawName's ${AppStrings.tr(language, 'wallet')}")
                  : AppStrings.tr(language, 'wallet');
            } else {
              displayedWalletAmount = activeBooklet.getMemberWallet(
                _selectedUserFilter,
                userBookletWallets: userBookletWallets,
              );
              final member = household?.members.where((m) => m.uid == _selectedUserFilter).firstOrNull;
              final rawName = shortName(member?.name ?? 'Member');
              walletCardTitle = rawName.length <= 7
                  ? (language == AppLanguage.tamil ? '$rawName வாலட்' : "$rawName's ${AppStrings.tr(language, 'wallet')}")
                  : AppStrings.tr(language, 'wallet');
            }
          } else {
            displayedWalletAmount = 0.0;
            walletCardTitle = isAllUsers
                ? AppStrings.tr(language, 'total_wallet')
                : (_selectedUserFilter == 'me'
                    ? AppStrings.tr(language, 'your_wallet')
                    : AppStrings.tr(language, 'wallet'));
          }

          // Balance calculation based on Wallet & Passbook In/Out
          final double remainingBalance;
          final String balanceCardTitle;
          final Color balanceColor;

          final walletReceived = filtered
              .where((t) => t.type == TransactionType.received && (t.category.toLowerCase() == 'wallet' || t.note?.toLowerCase() == 'wallet deposit'))
              .fold(0.0, (acc, t) => acc + t.amount);
          final nonWalletReceived = totalReceived - walletReceived;

          if (displayedWalletAmount > 0) {
            remainingBalance = displayedWalletAmount + nonWalletReceived - totalPaid;
            if (isAllUsers) {
              balanceCardTitle = AppStrings.tr(language, 'group_balance');
            } else if (_selectedUserFilter == 'me') {
              balanceCardTitle = AppStrings.tr(language, 'your_balance');
            } else {
              final member = household?.members.where((m) => m.uid == _selectedUserFilter).firstOrNull ?? partner;
              final rawName = shortName(member?.name ?? 'Member');
              balanceCardTitle = rawName.length <= 7
                  ? (language == AppLanguage.tamil ? '$rawName இருப்பு' : "$rawName's ${AppStrings.tr(language, 'balance')}")
                  : AppStrings.tr(language, 'balance');
            }
            balanceColor = remainingBalance >= 0 ? Colors.green.shade700 : Colors.red.shade700;
          } else {
            remainingBalance = totalReceived - totalPaid;
            balanceCardTitle = isAllUsers
                ? AppStrings.tr(language, 'group_balance')
                : (_selectedUserFilter == 'me'
                    ? AppStrings.tr(language, 'your_balance')
                    : AppStrings.tr(language, 'balance'));
            balanceColor = remainingBalance >= 0 ? Colors.green.shade700 : Colors.red.shade700;
          }

          // Calculate cumulative running passbook balance across active booklet transactions
          final chronologicalTx = List<TransactionModel>.from(activeBookletTransactions)
            ..sort((a, b) => a.date.compareTo(b.date));

          final runningBalanceMap = <String, double>{};
          double runningBal = 0.0;
          for (final tx in chronologicalTx) {
            if (tx.type == TransactionType.received) {
              runningBal += tx.amount;
            } else {
              runningBal -= tx.amount;
            }
            runningBalanceMap[tx.id] = runningBal;
          }

          // Sort filtered transactions descending by date
          final sortedFiltered = List<TransactionModel>.from(filtered)
            ..sort((a, b) => b.date.compareTo(a.date));

          // Group by Date: e.g. "Wed, 04 Nov 2026"
          final groupedTransactions = <String, List<TransactionModel>>{};
          for (final tx in sortedFiltered) {
            final dateKey = DateFormat('EEE, dd MMM yyyy').format(tx.date);
            groupedTransactions.putIfAbsent(dateKey, () => []).add(tx);
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
              // Category Budget Alert Banner (shows if any category is >=80% or exceeded)
              BudgetAlertCard(transactions: filtered),
              // Sub-header Row (Cash In / Cash Out Passbook Style)
              Container(
                color: Theme.of(context).colorScheme.primaryContainer,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Text(
                        AppStrings.tr(language, 'date'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        AppStrings.tr(language, 'cash_in'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.green),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        AppStrings.tr(language, 'cash_out'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.red),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              // List Grouped by Date (Under each date, that day's transactions are listed)
              Expanded(
                child: groupedTransactions.isEmpty
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
                    : ListView.builder(
                        itemCount: groupedTransactions.length,
                        itemBuilder: (context, groupIndex) {
                          final dateKey = groupedTransactions.keys.elementAt(groupIndex);
                          final txList = groupedTransactions[dateKey]!;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Date Header Banner (e.g. "Wed, 04 Nov 2026")
                              Container(
                                width: double.infinity,
                                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                                child: Text(
                                  dateKey,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              // Day's Transactions
                              ...txList.map((tx) {
                                final isMe = tx.paidByUid == currentUser.uid;
                                final isPaid = tx.type == TransactionType.paid;
                                final color = isPaid ? Colors.red.shade700 : Colors.green.shade700;
                                final isWallet = tx.category.toLowerCase() == 'wallet';
                                final titleText = isWallet
                                    ? AppStrings.tr(language, 'wallet_incoming')
                                    : ((tx.note != null && tx.note!.trim().isNotEmpty)
                                        ? tx.note!.trim()
                                        : (tx.category.isNotEmpty ? tx.category : AppStrings.tr(language, 'other')));
                                final runningBal = runningBalanceMap[tx.id] ?? 0.0;

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
                                      final deleterName = household.members
                                          .where((m) => m.uid == currentUser.uid)
                                          .firstOrNull
                                          ?.name ??
                                          currentUser.displayName ??
                                          'Member';
                                      final booklets = ref.read(bookletsStreamProvider).asData?.value ?? [];
                                      final bName = booklets
                                          .where((b) => b.id == tx.bookletId)
                                          .firstOrNull
                                          ?.name ??
                                          'Main Cashbook';

                                      await ref.read(transactionRepositoryProvider).deleteTransaction(
                                            household.id,
                                            tx.id,
                                            deletedByUid: currentUser.uid,
                                            deletedByName: deleterName,
                                            bookletName: bName,
                                            transactionData: tx,
                                          );
                                      if (tx.category.toLowerCase() == 'wallet') {
                                        await ref.read(walletRepositoryProvider).setWalletAmount(
                                              tx.paidByUid,
                                              0,
                                              householdId: household.id,
                                              bookletId: tx.bookletId,
                                            );
                                      }
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
                                      if (isWallet) {
                                        _showWalletDialog(
                                          currentAmount: tx.amount,
                                          uid: tx.paidByUid,
                                          activeBooklet: activeBooklet,
                                          selectedUserFilter: tx.paidByUid,
                                        );
                                        return;
                                      }
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
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                                            width: 0.5,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          // Left Column: Category Emoji + Title & Subtitle (Time • Member)
                                          Expanded(
                                            flex: 7,
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 34,
                                                  height: 34,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    color: color.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    isWallet ? '💰' : getCategoryEmoji(titleText),
                                                    style: const TextStyle(fontSize: 16),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
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
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Row(
                                                        children: [
                                                          Text(
                                                            DateFormat('hh:mm a').format(tx.date),
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: onSurfaceVariant,
                                                            ),
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            '•',
                                                            style: TextStyle(fontSize: 10, color: onSurfaceVariant),
                                                          ),
                                                          const SizedBox(width: 4),
                                                          Flexible(
                                                            child: Text(
                                                              isMe
                                                                  ? AppStrings.tr(language, 'you')
                                                                  : (tx.paidByName.isNotEmpty
                                                                      ? shortName(tx.paidByName)
                                                                      : partnerName),
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight: isMe ? FontWeight.w600 : FontWeight.normal,
                                                                color: isMe ? Theme.of(context).colorScheme.primary : onSurfaceVariant,
                                                              ),
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                          ),
                                                          if (tx.receiptUrl != null && tx.receiptUrl!.isNotEmpty) ...[
                                                            const SizedBox(width: 6),
                                                            GestureDetector(
                                                              onTap: () => ReceiptViewerDialog.show(
                                                                context,
                                                                receiptPath: tx.receiptUrl!,
                                                                title: titleText,
                                                                amountText: _currencyFormat.format(tx.amount),
                                                              ),
                                                              child: Icon(Icons.receipt_long, size: 12, color: Theme.of(context).colorScheme.primary),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Right Column: Amount (Cash In / Cash Out) & Running Balance
                                          Expanded(
                                            flex: 5,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _currencyFormat.format(tx.amount),
                                                  style: TextStyle(
                                                    color: color,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                  textAlign: TextAlign.right,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${AppStrings.tr(language, 'balance')} ${_currencyFormat.format(runningBal)}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: onSurfaceVariant,
                                                  ),
                                                  textAlign: TextAlign.right,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
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
                            _showWalletDialog(
                              currentAmount: displayedWalletAmount,
                              uid: currentUser.uid,
                              activeBooklet: activeBooklet,
                              selectedUserFilter: _selectedUserFilter,
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        walletCardTitle,
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(Icons.edit, size: 10, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    preferences.isPrivacyMode
                                        ? '₹••••'
                                        : (displayedWalletAmount > 0 ? _currencyFormat.format(displayedWalletAmount) : 'Set ₹'),
                                    style: TextStyle(
                                      color: displayedWalletAmount > 0 ? Theme.of(context).colorScheme.primary : onSurfaceVariant,
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
                      // 4. Balance (Remaining)
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            if (displayedWalletAmount <= 0) {
                              _showWalletDialog(
                                currentAmount: displayedWalletAmount,
                                uid: currentUser.uid,
                                activeBooklet: activeBooklet,
                                selectedUserFilter: _selectedUserFilter,
                              );
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
                                    balanceCardTitle,
                                    style: TextStyle(
                                      color: balanceColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    preferences.isPrivacyMode
                                        ? '₹••••'
                                        : (displayedWalletAmount > 0
                                            ? _currencyFormat.format(remainingBalance)
                                            : (net.abs() < 0.01 ? AppStrings.tr(language, 'no_due') : '₹${net.abs().toStringAsFixed(0)}')),
                                    style: TextStyle(
                                      color: balanceColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                if (displayedWalletAmount <= 0 && net.abs() >= 0.01)
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      net > 0 ? '(Cr)' : '(Dr)',
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

class _DashboardKeywordSearchDialog extends ConsumerStatefulWidget {
  final String initialKeyword;

  const _DashboardKeywordSearchDialog({required this.initialKeyword});

  @override
  ConsumerState<_DashboardKeywordSearchDialog> createState() => _DashboardKeywordSearchDialogState();
}

class _DashboardKeywordSearchDialogState extends ConsumerState<_DashboardKeywordSearchDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialKeyword);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageControllerProvider);

    return AlertDialog(
      title: Text(AppStrings.tr(language, 'search_title')),
      content: TextField(
        controller: _controller,
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
            Navigator.pop(context, _controller.text.trim());
          },
          child: Text(AppStrings.tr(language, 'search_title')),
        ),
      ],
    );
  }
}

class _DashboardWalletDialog extends ConsumerStatefulWidget {
  final double currentAmount;
  final String uid;
  final BookletModel? activeBooklet;
  final String selectedUserFilter;
  final String? householdId;

  const _DashboardWalletDialog({
    required this.currentAmount,
    required this.uid,
    this.activeBooklet,
    this.selectedUserFilter = 'all',
    this.householdId,
  });

  @override
  ConsumerState<_DashboardWalletDialog> createState() => _DashboardWalletDialogState();
}

class _DashboardWalletDialogState extends ConsumerState<_DashboardWalletDialog> {
  late final TextEditingController _controller;
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  late String _targetUid;
  String? _selectedBookletId;

  @override
  void initState() {
    super.initState();
    final filter = widget.selectedUserFilter;
    if (filter != 'all' && filter != 'me' && filter != 'group') {
      _targetUid = filter;
    } else {
      _targetUid = widget.uid;
    }

    _selectedBookletId = widget.activeBooklet?.id;

    final initialAmount = widget.activeBooklet?.getMemberWallet(_targetUid) ?? widget.currentAmount;
    _controller = TextEditingController(
      text: initialAmount > 0 ? initialAmount.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _switchMember(String newUid, BookletModel? booklet, Map<String, double> userBookletWallets) {
    if (_targetUid == newUid) return;
    setState(() {
      _targetUid = newUid;
      final val = booklet?.getMemberWallet(newUid, userBookletWallets: userBookletWallets) ?? 0.0;
      _controller.text = val > 0 ? val.toStringAsFixed(0) : '';
    });
  }

  Future<void> _handleSave(BookletModel? currentBooklet) async {
    final language = ref.read(languageControllerProvider);
    final raw = _controller.text.trim().toLowerCase();
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
        final household = ref.read(currentHouseholdProvider).asData?.value;
        final targetMemberName = household?.members.where((m) => m.uid == _targetUid).firstOrNull?.name ?? 'Member';
        await ref.read(walletRepositoryProvider).setWalletAmount(
              _targetUid,
              parsed,
              householdId: widget.householdId,
              bookletId: _selectedBookletId,
              userName: targetMemberName,
            );
        final bookletName = currentBooklet?.name ?? AppStrings.tr(language, 'wallet');
        messenger.showSnackBar(
          SnackBar(
            content: Text('$bookletName: ${_currencyFormat.format(parsed)}'),
          ),
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
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageControllerProvider);
    final household = ref.watch(currentHouseholdProvider).asData?.value;
    final members = household?.members ?? [];
    final allBooklets = ref.watch(bookletsStreamProvider).asData?.value ?? [];
    final userBookletWallets = ref.watch(userBookletWalletsProvider).asData?.value ?? {};

    BookletModel? currentBooklet;
    if (_selectedBookletId != null) {
      currentBooklet = allBooklets.where((b) => b.id == _selectedBookletId).firstOrNull;
    }
    currentBooklet ??= widget.activeBooklet ?? (allBooklets.isNotEmpty ? allBooklets.first : null);
    _selectedBookletId ??= currentBooklet?.id;

    final bookletName = currentBooklet?.name ?? 'Main Cashbook';
    final totalWallet = currentBooklet?.getTotalWalletAmount(
      userBookletWallets: userBookletWallets,
      currentUid: widget.uid,
    ) ?? 0.0;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.account_balance_wallet, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              currentBooklet != null
                  ? '$bookletName Wallet'
                  : AppStrings.tr(language, 'wallet_amount'),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (allBooklets.length > 1) ...[
              Text(
                AppStrings.tr(language, 'booklet'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: allBooklets.map((b) {
                    final isSel = b.id == _selectedBookletId;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ChoiceChip(
                        avatar: Icon(Icons.menu_book_rounded, size: 14, color: isSel ? Colors.white : Colors.blue),
                        label: Text(b.name, style: const TextStyle(fontSize: 12)),
                        selected: isSel,
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _selectedBookletId = b.id;
                              final amt = b.getMemberWallet(_targetUid, userBookletWallets: userBookletWallets);
                              _controller.text = amt > 0 ? amt.toStringAsFixed(0) : '';
                            });
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
            ] else if (currentBooklet != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.menu_book_rounded, size: 14, color: Colors.blueAccent),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Cashbook: $bookletName',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (members.length > 1) ...[
              Text(
                AppStrings.tr(language, 'member_wallets'),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: members.map((m) {
                  final isSelected = m.uid == _targetUid;
                  final isMe = m.uid == widget.uid;
                  final memberAmount = currentBooklet?.getMemberWallet(m.uid, userBookletWallets: userBookletWallets) ?? 0.0;
                  final label = '${isMe ? AppStrings.tr(language, "you") : shortName(m.name)} (₹${memberAmount.toStringAsFixed(0)})';
                  return ChoiceChip(
                    label: Text(label, style: const TextStyle(fontSize: 11)),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) _switchMember(m.uid, currentBooklet, userBookletWallets);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            Text(
              AppStrings.tr(language, 'wallet_desc'),
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [500, 1000, 1500, 2000, 3000, 5000, 10000].map((preset) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ActionChip(
                      label: Text('₹$preset', style: const TextStyle(fontSize: 12)),
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                      onPressed: () {
                        _controller.text = preset.toString();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            if (currentBooklet != null && totalWallet > 0) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.groups_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${AppStrings.tr(language, "combined_wallet")}: ${_currencyFormat.format(totalWallet)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppStrings.tr(language, 'cancel')),
        ),
        FilledButton(
          onPressed: () => _handleSave(currentBooklet),
          child: Text(AppStrings.tr(language, 'save')),
        ),
      ],
    );
  }
}

class _DashboardAmountFilterDialog extends ConsumerStatefulWidget {
  final double? minAmount;
  final double? maxAmount;

  const _DashboardAmountFilterDialog({
    required this.minAmount,
    required this.maxAmount,
  });

  @override
  ConsumerState<_DashboardAmountFilterDialog> createState() => _DashboardAmountFilterDialogState();
}

class _DashboardAmountFilterDialogState extends ConsumerState<_DashboardAmountFilterDialog> {
  late final TextEditingController _minController;
  late final TextEditingController _maxController;

  @override
  void initState() {
    super.initState();
    _minController = TextEditingController(
      text: widget.minAmount != null ? widget.minAmount!.toStringAsFixed(0) : '',
    );
    _maxController = TextEditingController(
      text: widget.maxAmount != null ? widget.maxAmount!.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageControllerProvider);

    return AlertDialog(
      title: Text(AppStrings.tr(language, 'filter_by_amount')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _minController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: AppStrings.tr(language, 'min_amount'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _maxController,
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
            Navigator.pop(context, {'min': null, 'max': null});
          },
          child: Text(AppStrings.tr(language, 'clear_filter')),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context, {
              'min': double.tryParse(_minController.text.trim()),
              'max': double.tryParse(_maxController.text.trim()),
            });
          },
          child: Text(AppStrings.tr(language, 'apply_filter')),
        ),
      ],
    );
  }
}
