import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:split_ledger/models/transaction_model.dart';
import 'package:split_ledger/core/services/csv_export_service.dart';

void main() {
  group('CsvExportService Unit Tests', () {
    test('generateCsvString outputs RFC compliant CSV with headers, escaping and metadata', () {
      final now = DateTime(2026, 10, 26, 14, 30);
      final txList = [
        TransactionModel(
          id: 'tx_1',
          amount: 1500.50,
          category: 'food',
          paidByUid: 'uid_1',
          paidByName: 'Praveen',
          note: 'Dinner at "Buhari", with drinks',
          date: now,
          type: TransactionType.paid,
          createdAt: now,
        ),
        TransactionModel(
          id: 'tx_2',
          amount: 2000.00,
          category: 'fuel',
          paidByUid: 'uid_2',
          paidByName: 'Kumar',
          note: 'Shell Petrol',
          date: now,
          type: TransactionType.paid,
          createdAt: now,
        ),
      ];

      final content = CsvExportService.generateCsvString(
        transactions: txList,
        householdName: 'My House',
        periodLabel: 'Oct 7 - Nov 6',
      );

      // Check metadata
      expect(content.contains('# SplitLedger Transaction Export'), isTrue);
      expect(content.contains('# Household / Group: My House'), isTrue);
      expect(content.contains('# Period / Cycle: Oct 7 - Nov 6'), isTrue);
      expect(content.contains('# Total Transactions: 2'), isTrue);
      expect(content.contains('# Total Group Expense: Rs. 3500.50'), isTrue);

      // Check header columns
      expect(content.contains('Date,Time,Category,Description,Type,Paid By,Amount (INR),Transaction ID'), isTrue);

      // Check quoted escaping for dinner with quotes & commas
      expect(content.contains('"Dinner at ""Buhari"", with drinks"'), isTrue);
      expect(content.contains('1500.50'), isTrue);
      expect(content.contains('2000.00'), isTrue);
    });

    test('exportTransactionsCsv writes file to custom Directory', () async {
      final now = DateTime(2026, 10, 26, 14, 30);
      final txList = [
        TransactionModel(
          id: 'tx_simple',
          amount: 500.0,
          category: 'tea',
          paidByUid: 'uid_1',
          paidByName: 'Praveen',
          date: now,
          type: TransactionType.paid,
          createdAt: now,
        ),
      ];

      final tempDir = Directory.systemTemp.createTempSync('split_test_');
      final file = await CsvExportService.exportTransactionsCsv(
        transactions: txList,
        householdName: 'Test Household',
        periodLabel: 'October 2026',
        customDir: tempDir,
      );

      expect(file.existsSync(), isTrue);
      final text = await file.readAsString();
      expect(text.contains('500.00'), isTrue);
      expect(text.contains('TEA'), isTrue);

      // Cleanup
      tempDir.deleteSync(recursive: true);
    });
  });
}
