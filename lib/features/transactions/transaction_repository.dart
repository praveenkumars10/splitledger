import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/transaction_model.dart';
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

  Future<void> deleteTransaction(String householdId, String transactionId) async {
    await _firestore
        .collection('households')
        .doc(householdId)
        .collection('transactions')
        .doc(transactionId)
        .delete();
  }

  Future<void> deleteAllTransactions(String householdId) async {
    final batch = _firestore.batch();
    final snapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('transactions')
        .get();
        
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    
    await batch.commit();
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
      batch.set(newDocRef, tx.copyWith(id: newDocRef.id, date: tx.nextOccurrence!, nextOccurrence: _calculateNext(tx.nextOccurrence!, tx.recurrence)).toMap());

      // Compute next occurrence for the original transaction
      final next = _calculateNext(tx.nextOccurrence!, tx.recurrence);
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

  DateTime _calculateNext(DateTime from, RecurrenceInterval interval) {
    switch (interval) {
      case RecurrenceInterval.daily:
        return from.add(const Duration(days: 1));
      case RecurrenceInterval.weekly:
        return from.add(const Duration(days: 7));
      case RecurrenceInterval.biweekly:
        return from.add(const Duration(days: 14));
      case RecurrenceInterval.monthly:
        return DateTime(from.year, from.month + 1, from.day, from.hour, from.minute);
      case RecurrenceInterval.yearly:
        return DateTime(from.year + 1, from.month, from.day, from.hour, from.minute);
      case RecurrenceInterval.none:
        return from;
    }
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
