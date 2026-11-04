import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/deleted_audit_item_model.dart';
import '../../models/transaction_model.dart';
import '../../models/booklet_model.dart';
import '../household/current_household_provider.dart';

final deletedHistoryRepositoryProvider = Provider<DeletedHistoryRepository>((ref) {
  return DeletedHistoryRepository();
});

/// Stream of deleted transactions and cashbooks for the current household.
/// Excludes records older than 90 days and triggers background cleanup.
final deletedHistoryStreamProvider = StreamProvider<List<DeletedAuditItemModel>>((ref) {
  final household = ref.watch(currentHouseholdProvider).asData?.value;
  if (household == null) return Stream.value([]);
  return ref.watch(deletedHistoryRepositoryProvider).watchDeletedHistory(household.id);
});

class DeletedHistoryRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Retention period for deleted history: 90 days (~3 months)
  static const Duration retentionPeriod = Duration(days: 90);

  CollectionReference<Map<String, dynamic>> _collection(String householdId) {
    return _firestore.collection('households').doc(householdId).collection('deleted_history');
  }

  /// Record a deleted transaction into the immutable audit history
  Future<void> recordDeletedTransaction({
    required String householdId,
    required TransactionModel transaction,
    required String deletedByUid,
    required String deletedByName,
    String? bookletName,
  }) async {
    try {
      final docRef = _collection(householdId).doc();
      final item = DeletedAuditItemModel.fromTransaction(
        id: docRef.id,
        transaction: transaction,
        deletedByUid: deletedByUid,
        deletedByName: deletedByName,
        bookletName: bookletName,
      );

      await docRef.set(item.toMap());

      // Trigger cleanup of any expired (>90 days) history in the background
      unawaited(purgeExpiredRecords(householdId));
    } catch (e) {
      // Log failure but do not throw to avoid blocking the primary deletion
      // ignore: avoid_print
      print('Failed to record deleted transaction audit log: $e');
    }
  }

  /// Record a deleted booklet/cashbook into the immutable audit history
  Future<void> recordDeletedBooklet({
    required String householdId,
    required BookletModel booklet,
    required String deletedByUid,
    required String deletedByName,
    int? transactionCount,
    double? totalAmount,
  }) async {
    try {
      final docRef = _collection(householdId).doc();
      final item = DeletedAuditItemModel.fromBooklet(
        id: docRef.id,
        booklet: booklet,
        deletedByUid: deletedByUid,
        deletedByName: deletedByName,
        transactionCount: transactionCount,
        totalAmount: totalAmount,
      );

      await docRef.set(item.toMap());

      // Trigger cleanup of any expired (>90 days) history in the background
      unawaited(purgeExpiredRecords(householdId));
    } catch (e) {
      // ignore: avoid_print
      print('Failed to record deleted booklet audit log: $e');
    }
  }

  /// Bulk record multiple deleted transactions (e.g. when a cashbook is deleted with its transactions)
  Future<void> recordDeletedTransactionsBatch({
    required String householdId,
    required List<TransactionModel> transactions,
    required String deletedByUid,
    required String deletedByName,
    String? bookletName,
  }) async {
    if (transactions.isEmpty) return;

    try {
      WriteBatch batch = _firestore.batch();
      int opCount = 0;
      final now = DateTime.now();

      for (final tx in transactions) {
        final docRef = _collection(householdId).doc();
        final item = DeletedAuditItemModel.fromTransaction(
          id: docRef.id,
          transaction: tx,
          deletedByUid: deletedByUid,
          deletedByName: deletedByName,
          bookletName: bookletName,
          deletedAt: now,
        );
        batch.set(docRef, item.toMap());
        opCount++;

        if (opCount >= 400) {
          await batch.commit();
          batch = _firestore.batch();
          opCount = 0;
        }
      }

      if (opCount > 0) {
        await batch.commit();
      }

      unawaited(purgeExpiredRecords(householdId));
    } catch (e) {
      // ignore: avoid_print
      print('Failed to bulk record deleted transactions audit log: $e');
    }
  }

  /// Automatically purges records older than 90 days (3 months)
  Future<void> purgeExpiredRecords(String householdId) async {
    try {
      final cutoff = DateTime.now().subtract(retentionPeriod);
      final querySnapshot = await _collection(householdId)
          .where('deletedAt', isLessThan: Timestamp.fromDate(cutoff))
          .limit(100)
          .get();

      if (querySnapshot.docs.isEmpty) return;

      WriteBatch batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      // Ignore background purge errors
      // ignore: avoid_print
      print('Background purge expired history encountered error: $e');
    }
  }

  /// Watches the deleted history stream.
  /// Automatically filters out any entry older than 90 days.
  Stream<List<DeletedAuditItemModel>> watchDeletedHistory(String householdId) {
    // Purge expired records asynchronously on stream subscription
    unawaited(purgeExpiredRecords(householdId));

    return _collection(householdId)
        .orderBy('deletedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final cutoff = DateTime.now().subtract(retentionPeriod);
      return snapshot.docs
          .map((doc) => DeletedAuditItemModel.fromMap(doc.data(), doc.id))
          .where((item) => item.deletedAt.isAfter(cutoff))
          .toList();
    });
  }
}

