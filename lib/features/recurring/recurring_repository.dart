import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/transaction_model.dart';
import '../household/current_household_provider.dart';
import '../transactions/transaction_repository.dart';
import 'models/recurring_expense_model.dart';

final recurringRepositoryProvider = Provider<RecurringRepository>((ref) {
  return RecurringRepository();
});

final currentRecurringExpensesProvider =
    StreamProvider<List<RecurringExpenseModel>>((ref) {
  final household = ref.watch(currentHouseholdProvider).asData?.value;
  if (household == null) return Stream.value([]);
  return ref.watch(recurringRepositoryProvider).watchRecurringExpenses(household.id);
});

class RecurringRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _localPrefix = 'offline_recurring_';

  Stream<List<RecurringExpenseModel>> watchRecurringExpenses(String householdId) {
    try {
      return _firestore
          .collection('households')
          .doc(householdId)
          .collection('recurring_expenses')
          .snapshots()
          .map((snapshot) {
        final list = snapshot.docs.map((doc) {
          return RecurringExpenseModel.fromMap(doc.data(), docId: doc.id);
        }).toList();
        // Sort by due day (1 to 31)
        list.sort((a, b) => a.dueDay.compareTo(b.dueDay));
        _saveToLocal(householdId, list);
        return list;
      }).handleError((_) => _loadFromLocalStream(householdId));
    } catch (_) {
      return _loadFromLocalStream(householdId);
    }
  }

  Stream<List<RecurringExpenseModel>> _loadFromLocalStream(String householdId) async* {
    final list = await _loadFromLocal(householdId);
    yield list;
  }

  Future<List<RecurringExpenseModel>> _loadFromLocal(String householdId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_localPrefix$householdId');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final list = decoded
            .map((item) => RecurringExpenseModel.fromMap(item as Map<String, dynamic>))
            .toList();
        list.sort((a, b) => a.dueDay.compareTo(b.dueDay));
        return list;
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveToLocal(String householdId, List<RecurringExpenseModel> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(items.map((i) => i.toMap()).toList());
      await prefs.setString('$_localPrefix$householdId', encoded);
    } catch (_) {}
  }

  Future<void> addRecurringExpense(
    String householdId,
    RecurringExpenseModel item,
  ) async {
    try {
      final docRef = _firestore
          .collection('households')
          .doc(householdId)
          .collection('recurring_expenses')
          .doc();

      final newItem = item.copyWith(id: docRef.id);
      await docRef.set(newItem.toMap());
    } catch (_) {
      // Local fallback
      final items = await _loadFromLocal(householdId);
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      items.add(item.copyWith(id: id));
      await _saveToLocal(householdId, items);
    }
  }

  Future<void> updateRecurringExpense(
    String householdId,
    RecurringExpenseModel item,
  ) async {
    try {
      await _firestore
          .collection('households')
          .doc(householdId)
          .collection('recurring_expenses')
          .doc(item.id)
          .update(item.toMap());
    } catch (_) {
      final items = await _loadFromLocal(householdId);
      final idx = items.indexWhere((i) => i.id == item.id);
      if (idx != -1) {
        items[idx] = item;
        await _saveToLocal(householdId, items);
      }
    }
  }

  Future<void> deleteRecurringExpense(
    String householdId,
    String itemId,
  ) async {
    try {
      await _firestore
          .collection('households')
          .doc(householdId)
          .collection('recurring_expenses')
          .doc(itemId)
          .delete();
    } catch (_) {
      final items = await _loadFromLocal(householdId);
      items.removeWhere((i) => i.id == itemId);
      await _saveToLocal(householdId, items);
    }
  }

  /// 1-Tap Log: creates a TransactionModel in transaction repository and updates lastLoggedCycle
  Future<void> logExpenseAsTransaction({
    required String householdId,
    required RecurringExpenseModel item,
    required TransactionRepository txRepo,
    required String cycleKey,
    DateTime? txDate,
  }) async {
    final now = txDate ?? DateTime.now();
    final newTx = TransactionModel(
      id: '',
      amount: item.amount,
      category: item.category,
      paidByUid: item.paidByUid,
      paidByName: item.paidByName,
      note: 'Recurring: ${item.title}',
      date: now,
      type: TransactionType.paid,
      createdAt: now,
    );

    await txRepo.addTransaction(householdId, newTx);

    // Update item lastLoggedCycle
    final updatedItem = item.copyWith(lastLoggedCycle: cycleKey);
    await updateRecurringExpense(householdId, updatedItem);
  }
}
