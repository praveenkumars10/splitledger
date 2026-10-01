import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/date_filters.dart';
import '../../core/group_split_calculator.dart';
import '../../core/utils.dart';
import '../../models/transaction_model.dart';
import '../auth/auth_controller.dart';
import '../household/current_household_provider.dart';
import '../transactions/transaction_repository.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
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

  Future<void> _exportPdf(GroupSplitResult split) async {
    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('SplitLedger Report', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text(_allTime ? 'All Time' : _monthFormat.format(_selectedMonth), style: const pw.TextStyle(fontSize: 18)),
              pw.SizedBox(height: 24),
              pw.Text('Total Group Expense: ${_currencyFormat.format(split.totalExpense).replaceAll('₹', 'Rs.')}'),
              pw.SizedBox(height: 16),
              ...split.balances.map((b) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text('${b.name} Paid: ${_currencyFormat.format(b.paid).replaceAll('₹', 'Rs.')}')
              )),
              pw.SizedBox(height: 24),
              if (split.isSettled)
                pw.Text('No due. You are all settled up!', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))
              else
                ...split.settlements.map((s) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Text(s.toString().replaceAll('₹', 'Rs.'), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                )),
            ],
          ),
        ),
      );

      final dir = await getTemporaryDirectory();
      final fileName = 'splitledger_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'SplitLedger Report',
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
      final periodName = _allTime ? 'All_Time' : _monthFormat.format(_selectedMonth).replaceAll(' ', '_');
      final file = File('${dir.path}/SplitLedger_Report_$periodName.csv');
      await file.writeAsString(buffer.toString());

      if (mounted) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'SplitLedger Report ($householdName - ${_allTime ? "All Time" : _monthFormat.format(_selectedMonth)})',
          ),
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

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text('Reports', style: TextStyle(color: Color(0xFF1C2434), fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1C2434)),
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
            padding: const EdgeInsets.all(24),
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
                      selectedColor: const Color(0xFF1C2434).withValues(alpha: 0.05),
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        color: _allTime ? const Color(0xFF1C2434) : Colors.grey,
                        fontWeight: _allTime ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: _allTime ? const Color(0xFF1C2434) : Colors.grey.withValues(alpha: 0.3)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: Text(_allTime ? 'Pick Month' : _monthFormat.format(_selectedMonth)),
                      selected: !_allTime,
                      onSelected: (selected) {
                        if (selected) _selectMonth();
                      },
                      selectedColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      showCheckmark: false,
                      avatar: !_allTime ? const Icon(Icons.calendar_today, size: 16, color: Color(0xFF4F46E5)) : null,
                      labelStyle: TextStyle(
                        color: !_allTime ? const Color(0xFF4F46E5) : Colors.grey,
                        fontWeight: !_allTime ? FontWeight.bold : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: !_allTime ? const Color(0xFF4F46E5).withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.3)),
                      ),
                    ),
                    if (!_allTime) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: Color(0xFF1C2434)),
                        onPressed: () => setState(() {
                          _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                        }),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: Color(0xFF1C2434)),
                        onPressed: () => setState(() {
                          _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                        }),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),

                // Summary cards
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        _allTime ? 'Total Group Expense' : 'Expense in ${_monthFormat.format(_selectedMonth)}',
                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _currencyFormat.format(split.totalExpense),
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Color(0xFF1C2434)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: split.balances.map((b) {
                    final color = Colors.primaries[split.balances.indexOf(b) % Colors.primaries.length];
                    return SizedBox(
                      width: (MediaQuery.of(context).size.width - 48 - 16) / 2,
                      child: _buildMetricCard('${b.name} Paid', b.paid, color),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Settlement
                if (split.isSettled)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: const Text('No due. You are all settled up!', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
                  )
                else
                  ...split.settlements.map((s) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Text(s.toString(), style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
                  )),
                const SizedBox(height: 24),

                // Chart
                SizedBox(
                  height: 260,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
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
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= split.balances.length) return const SizedBox();
                                final label = shortName(split.balances[index].name);
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    label, 
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
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
                              reservedSize: 46,
                              getTitlesWidget: (value, meta) {
                                if (value == 0) return const SizedBox();
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Text(
                                    NumberFormat.compact().format(value), 
                                    style: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
                                    textAlign: TextAlign.right,
                                  ),
                                );
                              }
                            ),
                          ),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          show: true, 
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey.withValues(alpha: 0.2),
                            strokeWidth: 1,
                            dashArray: [5, 5],
                          ),
                        ),
                        barGroups: split.balances.asMap().entries.map((e) {
                          final color = Colors.primaries[e.key % Colors.primaries.length];
                          return BarChartGroupData(
                            x: e.key,
                            barRods: [
                              BarChartRodData(
                                toY: e.value.paid,
                                color: color,
                                width: split.balances.length > 2 ? 24 : 32,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Export buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _exportPdf(split),
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                        label: const Text('Export PDF', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1C2434),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _exportCsv(periodTransactions, household?.name ?? 'Household'),
                        icon: const Icon(Icons.table_chart_outlined, color: Colors.white),
                        label: const Text('Export CSV', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(String title, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: color.withValues(alpha: 0.8), fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 8),
          Text(
            _currencyFormat.format(amount),
            style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
