import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/group_split_calculator.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/language_controller.dart';
import '../../core/preferences/app_preferences.dart';
import '../../core/services/csv_export_service.dart';
import '../../core/utils.dart';
import '../../models/transaction_model.dart';
import '../auth/auth_controller.dart';
import '../household/current_household_provider.dart';
import '../transactions/transaction_repository.dart';
import '../wallet/wallet_repository.dart';
import '../booklet/booklet_repository.dart';
import '../booklet/widgets/booklet_selector_bar.dart';
import 'widgets/category_breakdown_card.dart';
import 'widgets/daily_budget_card.dart';
import '../budget/widgets/budget_alert_card.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  DateTime _selectedMonth = DateTime.now();
  bool _allTime = false;
  bool _byMonth = false;

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
        _byMonth = true;
      });
    }
  }

  Future<void> _exportPdf(
    GroupSplitResult split,
    List<TransactionModel> periodTransactions,
    String householdName, {
    String? periodLabel,
  }) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('SplitLedger Expense Statement', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  pw.Text(periodLabel ?? (_allTime ? 'All Time' : _monthFormat.format(_selectedMonth)), style: const pw.TextStyle(fontSize: 14)),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Text('Group / Household: $householdName', style: const pw.TextStyle(fontSize: 14)),
            pw.Text('Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
            pw.Divider(),
            pw.SizedBox(height: 12),
            pw.Text('Total Group Expense: Rs. ${split.totalExpense.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Text('Member Contributions:', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            ...split.balances.map((b) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(b.name),
                  pw.Text('Rs. ${b.paid.toStringAsFixed(2)}'),
                ],
              ),
            )),
            pw.SizedBox(height: 16),
            pw.Text('Settlements & Dues:', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            if (split.isSettled)
              pw.Text('All settled up! No dues pending.', style: const pw.TextStyle(color: PdfColors.green700))
            else
              ...split.settlements.map((s) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text('• ${s.toString().replaceAll('₹', 'Rs. ')}', style: const pw.TextStyle(color: PdfColors.red700)),
              )),
            pw.SizedBox(height: 20),
            pw.Text('Transaction Log (${periodTransactions.length} items):', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Category', 'Description', 'Paid By', 'Amount'],
              data: periodTransactions.map((tx) => [
                DateFormat('dd/MM/yyyy').format(tx.date),
                tx.category.toUpperCase(),
                tx.note ?? '-',
                tx.paidByName,
                'Rs. ${tx.amount.toStringAsFixed(2)}',
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ],
        ),
      );

      final dir = await getTemporaryDirectory();
      final fileName = 'SplitLedger_Statement_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'SplitLedger Expense Statement for $householdName',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export PDF: $e')),
        );
      }
    }
  }

  Future<void> _exportCsv(
    List<TransactionModel> transactions,
    String householdName, {
    String? periodLabel,
  }) async {
    try {
      final file = await CsvExportService.exportTransactionsCsv(
        transactions: transactions,
        householdName: householdName,
        periodLabel: periodLabel ?? (_allTime ? 'All Time' : _monthFormat.format(_selectedMonth)),
      );

      if (mounted) {
        await CsvExportService.shareCsvFile(
          file: file,
          householdName: householdName,
          periodLabel: periodLabel ?? (_allTime ? 'All Time' : _monthFormat.format(_selectedMonth)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV Export failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(currentTransactionsProvider);
    final currentUser = ref.watch(authStateChangesProvider).asData?.value;
    final household = ref.watch(currentHouseholdProvider).asData?.value;
    final walletAmount = ref.watch(currentWalletAmountProvider).asData?.value ?? 0.0;
    final language = ref.watch(languageControllerProvider);
    final preferences = ref.watch(appPreferencesProvider);
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    final cycleStartDay = household?.cycleStartDay ?? preferences.cycleStartDay;
    final activeBooklet = ref.watch(activeBookletProvider);
    final activeBookletTx = ref.watch(activeBookletTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(language, 'reports_tab')),
        centerTitle: false,
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

          final periodTransactions = _allTime
              ? transactions
              : (_byMonth
                  ? transactions.where((tx) => tx.date.year == _selectedMonth.year && tx.date.month == _selectedMonth.month).toList()
                  : activeBookletTx);

          final periodLabel = _allTime
              ? 'All Time'
              : (_byMonth ? _monthFormat.format(_selectedMonth) : (activeBooklet?.name ?? 'Cashbook'));

          final groupMembers = household?.members.map((m) => (uid: m.uid, name: m.name)).toList() ?? [];
          final split = calculateGroupSplit(
            transactions: periodTransactions,
            members: groupMembers,
          );

          final userSpend = periodTransactions
              .where((t) => t.paidByUid == currentUser.uid && t.type == TransactionType.paid && t.category.toLowerCase() != 'settlement')
              .fold(0.0, (sum, t) => sum + t.amount);

          return SingleChildScrollView(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 90),
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
                        selected: !_allTime && !_byMonth,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _allTime = false;
                              _byMonth = false;
                            });
                          } else {
                            showBookletSwitchSheet(context);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      // By Month Chip
                      ChoiceChip(
                        avatar: const Icon(Icons.calendar_month, size: 16),
                        label: Text(_monthFormat.format(_selectedMonth)),
                        selected: !_allTime && _byMonth,
                        onSelected: (selected) {
                          _selectMonth();
                        },
                      ),
                      const SizedBox(width: 8),
                      // All Time Chip
                      ChoiceChip(
                        label: Text(AppStrings.tr(language, 'all_time')),
                        selected: _allTime,
                        onSelected: (selected) => setState(() {
                          _allTime = selected;
                          if (selected) _byMonth = false;
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Daily Budget Card
                DailyBudgetCard(
                  walletAmount: walletAmount,
                  userTotalSpend: userSpend,
                  cycleStartDay: cycleStartDay,
                ),
                const SizedBox(height: 16),

                // Summary cards
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          _allTime
                              ? AppStrings.tr(language, 'total_group_expense')
                              : '${AppStrings.tr(language, 'total_group_expense')} (${_monthFormat.format(_selectedMonth)})',
                          style: TextStyle(color: onSurfaceVariant, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currencyFormat.format(split.totalExpense),
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Member metric cards with LayoutBuilder
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
                            child: _buildMetricCard('${b.name} ${AppStrings.tr(language, 'you_paid')}', b.paid, color),
                          );
                        }).toList(),
                      );
                    },
                  ),
                const SizedBox(height: 20),

                // Budget Alert Card (if any category is >=80% or exceeded)
                BudgetAlertCard(transactions: periodTransactions),

                // Category Breakdown Card
                CategoryBreakdownCard(transactions: periodTransactions),
                const SizedBox(height: 20),

                // Visual Chart
                if (split.balances.isNotEmpty)
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.tr(language, 'spending_by_member'),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 220,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: split.balances.isEmpty ? 100 : (split.balances.map((b) => b.paid).reduce((a, b) => a > b ? a : b)) * 1.2 + 10,
                                barTouchData: BarTouchData(enabled: true),
                                titlesData: FlTitlesData(
                                  show: true,
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 32,
                                      getTitlesWidget: (value, meta) {
                                        final index = value.toInt();
                                        if (index < 0 || index >= split.balances.length) return const SizedBox();
                                        final label = shortName(split.balances[index].name);
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Text(
                                            label,
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 42,
                                      getTitlesWidget: (value, meta) {
                                        if (value == 0) return const SizedBox();
                                        return Text(
                                          NumberFormat.compact().format(value),
                                          style: TextStyle(fontSize: 10, color: onSurfaceVariant),
                                        );
                                      },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                borderData: FlBorderData(show: false),
                                gridData: const FlGridData(show: true, drawVerticalLine: false),
                                barGroups: split.balances.asMap().entries.map((e) {
                                  final color = Colors.primaries[e.key % Colors.primaries.length];
                                  return BarChartGroupData(
                                    x: e.key,
                                    barRods: [
                                      BarChartRodData(
                                        toY: e.value.paid,
                                        color: color,
                                        width: split.balances.length > 3 ? 18 : 26,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // Export buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _exportPdf(
                          split,
                          periodTransactions,
                          household?.name ?? 'Household',
                          periodLabel: periodLabel,
                        ),
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                        label: Text(AppStrings.tr(language, 'export_pdf'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _exportCsv(
                          periodTransactions,
                          household?.name ?? 'Household',
                          periodLabel: periodLabel,
                        ),
                        icon: const Icon(Icons.table_chart_outlined, color: Colors.white),
                        label: Text(AppStrings.tr(language, 'export_csv'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(String title, double amount, Color color) {
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              _currencyFormat.format(amount),
              style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
