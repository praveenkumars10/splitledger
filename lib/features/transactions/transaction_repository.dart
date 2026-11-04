import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/transaction_model.dart';
import '../../models/deleted_audit_item_model.dart';
import '../household/current_household_provider.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository();
});

final currentTransactionsProvider = StreamProvider<List<TransactionModel>>((ref) {
  final household = ref.watch(currentHouseholdProvider).asData?.value;
  if (household == null) return Stream.value([]);
  return ref.watch(transactionRepositoryProvider).watchTransactions(household.id);
});

class TransactionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> addTransaction(String householdId, TransactionModel transaction) async {
    final docRef = _firestore
        .collection('households')
        .doc(householdId)
        .collection('transactions')
        .doc();
        
    final newTx = TransactionModel(
      id: docRef.id,
      amount: transaction.amount,
      category: transaction.category,
      paidByUid: transaction.paidByUid,
      paidByName: transaction.paidByName,
      note: transaction.note,
      receiptUrl: transaction.receiptUrl,
      date: transaction.date,
      dueDate: transaction.dueDate,
      type: transaction.type,
      createdAt: transaction.createdAt,
      splitPercentages: transaction.splitPercentages,
      splitShares: transaction.splitShares,
      recurrence: transaction.recurrence,
      recurrenceEndDate: transaction.recurrenceEndDate,
      nextOccurrence: transaction.nextOccurrence,
      bookletId: transaction.bookletId,
    );

    await docRef.set(newTx.toMap());
  }

  Future<void> updateTransaction(String householdId, TransactionModel transaction) async {
    await _firestore
        .collection('households')
        .doc(householdId)
        .collection('transactions')
        .doc(transaction.id)
        .update(transaction.toMap());
  }

  Future<void> deleteTransaction(
    String householdId,
    String transactionId, {
    String? deletedByUid,
    String? deletedByName,
    String? bookletName,
    TransactionModel? transactionData,
  }) async {
    final docRef = _firestore
        .collection('households')
        .doc(householdId)
        .collection('transactions')
        .doc(transactionId);

    // Record to deleted_history audit log before deleting
    try {
      TransactionModel? tx = transactionData;
      if (tx == null) {
        final docSnap = await docRef.get();
        if (docSnap.exists && docSnap.data() != null) {
          tx = TransactionModel.fromMap(docSnap.data()!, docSnap.id);
        }
      }

      if (tx != null) {
        final auditRef = _firestore
            .collection('households')
            .doc(householdId)
            .collection('deleted_history')
            .doc();

        final auditItem = DeletedAuditItemModel.fromTransaction(
          id: auditRef.id,
          transaction: tx,
          deletedByUid: deletedByUid ?? '',
          deletedByName: (deletedByName != null && deletedByName.trim().isNotEmpty)
              ? deletedByName
              : 'Member',
          bookletName: bookletName,
        );

        await auditRef.set(auditItem.toMap());
      }
    } catch (e) {
      // ignore: avoid_print
      print('Failed to record transaction deletion to audit log: $e');
    }

    await docRef.delete();
  }

  Future<void> deleteAllTransactions(
    String householdId, {
    String? deletedByUid,
    String? deletedByName,
  }) async {
    final snapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('transactions')
        .get();

    final now = DateTime.now();
    for (final doc in snapshot.docs) {
      try {
        final tx = TransactionModel.fromMap(doc.data(), doc.id);
        final auditRef = _firestore
            .collection('households')
            .doc(householdId)
            .collection('deleted_history')
            .doc();

        final auditItem = DeletedAuditItemModel.fromTransaction(
          id: auditRef.id,
          transaction: tx,
          deletedByUid: deletedByUid ?? '',
          deletedByName: (deletedByName != null && deletedByName.trim().isNotEmpty)
              ? deletedByName
              : 'Member',
          deletedAt: now,
        );
        await auditRef.set(auditItem.toMap());
      } catch (_) {}
    }

    WriteBatch batch = _firestore.batch();
    int opCount = 0;
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
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
  }


  Future<void> generateRecurringTransactions(String householdId) async {
    final now = Timestamp.now();
    final query = _firestore
        .collection('households')
        .doc(householdId)
        .collection('transactions')
        .where('recurrence', isNotEqualTo: 'none')
        .where('nextOccurrence', isLessThanOrEqualTo: now);

    final snapshot = await query.get();
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      final tx = TransactionModel.fromMap(doc.data(), doc.id);
      
      // Add the new transaction as a new document
      final newDocRef = _firestore
          .collection('households')
          .doc(householdId)
          .collection('transactions')
          .doc();
      final next = TransactionModel.calculateNextOccurrence(tx.nextOccurrence!, tx.recurrence);
      batch.set(newDocRef, tx.copyWith(id: newDocRef.id, date: tx.nextOccurrence!, nextOccurrence: next).toMap());

      // Compute next occurrence for the original transaction
      if (tx.recurrenceEndDate != null && next.isAfter(tx.recurrenceEndDate!)) {
        // End of recurrence: clear recurrence fields
        batch.update(doc.reference, {
          'recurrence': 'none',
          'nextOccurrence': null,
        });
      } else {
        batch.update(doc.reference, {'nextOccurrence': Timestamp.fromDate(next)});
      }
    }
    await batch.commit();
  }
  Stream<List<TransactionModel>> watchTransactions(String householdId, {DateTime? startDate, DateTime? endDate}) {
    var query = _firestore
        .collection('households')
        .doc(householdId)
        .collection('transactions')
        .orderBy('date', descending: true);

    if (startDate != null) {
      query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
    }
    if (endDate != null) {
      query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => TransactionModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

}
