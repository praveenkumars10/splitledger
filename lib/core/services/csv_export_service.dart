import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/transaction_model.dart';

class CsvExportService {
  /// Generates the pure RFC 4180 CSV string without filesystem dependency
  static String generateCsvString({
    required List<TransactionModel> transactions,
    required String householdName,
    String? periodLabel,
  }) {
    final buffer = StringBuffer();
    final now = DateTime.now();
    final generatedStr = DateFormat('dd MMM yyyy, hh:mm a').format(now);

    // Metadata header
    buffer.writeln('# SplitLedger Transaction Export');
    buffer.writeln('# Household / Group: $householdName');
    if (periodLabel != null && periodLabel.isNotEmpty) {
      buffer.writeln('# Period / Cycle: $periodLabel');
    }
    buffer.writeln('# Generated: $generatedStr');
    buffer.writeln('# Total Transactions: ${transactions.length}');

    final totalExpense = transactions
        .where((t) => t.type == TransactionType.paid && t.category.toLowerCase() != 'settlement')
        .fold(0.0, (sum, t) => sum + t.amount);
    buffer.writeln('# Total Group Expense: Rs. ${totalExpense.toStringAsFixed(2)}');
    buffer.writeln(); // Empty line before table

    // CSV Columns
    buffer.writeln('Date,Time,Category,Description,Type,Paid By,Amount (INR),Transaction ID');

    for (final tx in transactions) {
      final dateStr = DateFormat('yyyy-MM-dd').format(tx.date);
      final timeStr = DateFormat('hh:mm a').format(tx.date);
      final catStr = _escapeCsv(tx.category.toUpperCase());
      final noteStr = _escapeCsv(tx.note ?? '-');
      final typeStr = tx.type == TransactionType.paid ? 'Expense' : 'Income';
      final payerStr = _escapeCsv(tx.paidByName);
      final amountStr = tx.amount.toStringAsFixed(2);
      final idStr = _escapeCsv(tx.id);

      buffer.writeln('$dateStr,$timeStr,$catStr,$noteStr,$typeStr,$payerStr,$amountStr,$idStr');
    }

    return buffer.toString();
  }

  /// Generates and writes an RFC 4180 compliant CSV file
  static Future<File> exportTransactionsCsv({
    required List<TransactionModel> transactions,
    required String householdName,
    String? periodLabel,
    Directory? customDir,
  }) async {
    final csvContent = generateCsvString(
      transactions: transactions,
      householdName: householdName,
      periodLabel: periodLabel,
    );

    final dir = customDir ?? await getTemporaryDirectory();
    final cleanPeriod = (periodLabel ?? 'All_Time')
        .replaceAll(' ', '_')
        .replaceAll('/', '-')
        .replaceAll(':', '-');
    final timeStamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'SplitLedger_${cleanPeriod}_$timeStamp.csv';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(csvContent);
    return file;
  }

  static Future<void> shareCsvFile({
    required File file,
    required String householdName,
    String? periodLabel,
  }) async {
    final period = periodLabel != null ? ' ($periodLabel)' : '';
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'SplitLedger Expense Data Export for $householdName$period',
      ),
    );
  }

  static String _escapeCsv(String val) {
    if (val.contains(',') || val.contains('"') || val.contains('\n') || val.contains('\r')) {
      return '"${val.replaceAll('"', '""')}"';
    }
    return val;
  }
}
