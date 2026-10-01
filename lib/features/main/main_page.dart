import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/language_controller.dart';
import '../../models/transaction_model.dart';
import '../dashboard/dashboard_page.dart';
import '../reports/reports_page.dart';
import '../split/split_summary_page.dart';
import '../transactions/add_transaction_page.dart';
import '../transactions/quick_add_bottom_sheet.dart';
import '../transactions/transaction_history_page.dart';

class MainPage extends ConsumerStatefulWidget {
  const MainPage({super.key});

  @override
  ConsumerState<MainPage> createState() => _MainPageState();
}

class _MainPageState extends ConsumerState<MainPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardPage(),
    SplitSummaryPage(),
    TransactionHistoryPage(),
    ReportsPage(),
  ];

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Add Transaction',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.bolt, color: Colors.amber, size: 24),
                ),
                title: const Text('1-Tap Quick Expense', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Add in 2 seconds with preset chips'),
                onTap: () {
                  Navigator.pop(context);
                  QuickAddBottomSheet.show(context);
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_upward, color: Colors.red, size: 24),
                ),
                title: const Text('You Paid (Full Details)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Custom split percentages, bills, & recurrence'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTransactionPage(type: TransactionType.paid)));
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_downward, color: Colors.green, size: 24),
                ),
                title: const Text('You Received (Cash In)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Record payments received from friends'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AddTransactionPage(type: TransactionType.received)));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageControllerProvider);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      floatingActionButton: FloatingActionButton(
        elevation: 4,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        shape: const CircleBorder(),
        tooltip: 'Add Transaction',
        onPressed: _showAddOptions,
        child: const Icon(Icons.add, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: NavigationBar(
          elevation: 8,
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() => _currentIndex = index),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: AppStrings.tr(language, 'home_tab'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.handshake_outlined),
              selectedIcon: const Icon(Icons.handshake),
              label: AppStrings.tr(language, 'split_tab'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: AppStrings.tr(language, 'history_tab'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.bar_chart_outlined),
              selectedIcon: const Icon(Icons.bar_chart),
              label: AppStrings.tr(language, 'reports_tab'),
            ),
          ],
        ),
      ),
    );
  }
}
