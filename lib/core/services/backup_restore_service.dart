import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/household_model.dart';
import '../../models/transaction_model.dart';
import '../../features/transactions/transaction_repository.dart';
import '../../features/wallet/wallet_repository.dart';

class BackupResult {
  final bool success;
  final String message;
  final int transactionCount;
  final double? walletAmount;

  BackupResult({
    required this.success,
    required this.message,
    this.transactionCount = 0,
    this.walletAmount,
  });
}

class BackupRestoreService {
  /// Export data as a formatted JSON file and share it via OS share sheet
  static Future<File?> exportBackup({
    required BuildContext context,
    required List<TransactionModel> transactions,
    required double walletAmount,
    required String householdName,
    required List<HouseholdMember> members,
  }) async {
    try {
      final now = DateTime.now();
      final backupData = {
        'version': 1,
        'appName': 'SplitLedger',
        'exportedAt': now.toIso8601String(),
        'householdName': householdName,
        'walletAmount': walletAmount,
        'memberCount': members.length,
        'members': members.map((m) => {'uid': m.uid, 'name': m.name}).toList(),
        'transactionCount': transactions.length,
        'transactions': transactions.map((t) => t.toJson()).toList(),
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(backupData);
      final dir = await getTemporaryDirectory();
      final dateSlug = DateFormat('yyyyMMdd_HHmmss').format(now);
      final fileName = 'SplitLedger_Backup_$dateSlug.json';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(jsonString);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'SplitLedger Data Backup ($householdName) - ${DateFormat('dd MMM yyyy').format(now)}',
        ),
      );

      return file;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
      return null;
    }
  }

  /// Parse and validate JSON backup string
  static Map<String, dynamic>? validateBackupJson(String rawJson) {
    try {
      final data = jsonDecode(rawJson);
      if (data is Map<String, dynamic> && data.containsKey('transactions')) {
        return data;
      }
    } catch (_) {}
    return null;
  }

  /// Restore data from JSON structure into the active household
  static Future<BackupResult> restoreFromJson({
    required WidgetRef ref,
    required String householdId,
    required String currentUid,
    required String rawJson,
    bool replaceExisting = false,
  }) async {
    try {
      final data = validateBackupJson(rawJson);
      if (data == null) {
        return BackupResult(
          success: false,
          message: 'Invalid SplitLedger JSON format. Please ensure you selected a valid backup file.',
        );
      }

      final rawList = data['transactions'] as List<dynamic>? ?? [];
      final transactionsToRestore = rawList
          .map((item) => TransactionModel.fromJson(item as Map<String, dynamic>))
          .toList();

      final txRepo = ref.read(transactionRepositoryProvider);

      if (replaceExisting) {
        await txRepo.deleteAllTransactions(householdId);
      }

      int importedCount = 0;
      for (final tx in transactionsToRestore) {
        // Create new ID to ensure clean insert
        final cleanTx = tx.copyWith(id: '');
        await txRepo.addTransaction(householdId, cleanTx);
        importedCount++;
      }

      // Restore wallet amount if present
      final backupWallet = (data['walletAmount'] as num?)?.toDouble();
      if (backupWallet != null && backupWallet > 0) {
        await ref.read(walletRepositoryProvider).setWalletAmount(currentUid, backupWallet);
      }

      return BackupResult(
        success: true,
        message: 'Successfully restored $importedCount transactions!',
        transactionCount: importedCount,
        walletAmount: backupWallet,
      );
    } catch (e) {
      return BackupResult(
        success: false,
        message: 'Failed to restore data: $e',
      );
    }
  }
}
