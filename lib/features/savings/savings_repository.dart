import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../household/current_household_provider.dart';
import 'models/savings_goal_model.dart';

final savingsRepositoryProvider = Provider<SavingsRepository>((ref) {
  return SavingsRepository();
});

final currentSavingsGoalsProvider =
    StreamProvider<List<SavingsGoalModel>>((ref) {
  final household = ref.watch(currentHouseholdProvider).asData?.value;
  if (household == null) return Stream.value([]);
  return ref.watch(savingsRepositoryProvider).watchSavingsGoals(household.id);
});

class SavingsRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const _localPrefix = 'offline_savings_';

  Stream<List<SavingsGoalModel>> watchSavingsGoals(String householdId) {
    try {
      return _firestore
          .collection('households')
          .doc(householdId)
          .collection('savings_goals')
          .snapshots()
          .map((snapshot) {
        final list = snapshot.docs.map((doc) {
          return SavingsGoalModel.fromMap(doc.data(), docId: doc.id);
        }).toList();
        // Incomplete goals first, then by highest percentage
        list.sort((a, b) {
          if (a.isCompleted != b.isCompleted) {
            return a.isCompleted ? 1 : -1;
          }
          return b.percentage.compareTo(a.percentage);
        });
        _saveToLocal(householdId, list);
        return list;
      }).handleError((_) => _loadFromLocalStream(householdId));
    } catch (_) {
      return _loadFromLocalStream(householdId);
    }
  }

  Stream<List<SavingsGoalModel>> _loadFromLocalStream(String householdId) async* {
    final list = await _loadFromLocal(householdId);
    yield list;
  }

  Future<List<SavingsGoalModel>> _loadFromLocal(String householdId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_localPrefix$householdId');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw) as List<dynamic>;
        final list = decoded
            .map((item) => SavingsGoalModel.fromMap(item as Map<String, dynamic>))
            .toList();
        list.sort((a, b) {
          if (a.isCompleted != b.isCompleted) {
            return a.isCompleted ? 1 : -1;
          }
          return b.percentage.compareTo(a.percentage);
        });
        return list;
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveToLocal(String householdId, List<SavingsGoalModel> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(items.map((i) => i.toMap()).toList());
      await prefs.setString('$_localPrefix$householdId', encoded);
    } catch (_) {}
  }

  Future<void> addGoal(String householdId, SavingsGoalModel goal) async {
    try {
      final docRef = _firestore
          .collection('households')
          .doc(householdId)
          .collection('savings_goals')
          .doc();

      final newGoal = goal.copyWith(id: docRef.id);
      await docRef.set(newGoal.toMap());
    } catch (_) {
      final items = await _loadFromLocal(householdId);
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      items.add(goal.copyWith(id: id));
      await _saveToLocal(householdId, items);
    }
  }

  Future<void> updateGoal(String householdId, SavingsGoalModel goal) async {
    try {
      await _firestore
          .collection('households')
          .doc(householdId)
          .collection('savings_goals')
          .doc(goal.id)
          .update(goal.toMap());
    } catch (_) {
      final items = await _loadFromLocal(householdId);
      final idx = items.indexWhere((i) => i.id == goal.id);
      if (idx != -1) {
        items[idx] = goal;
        await _saveToLocal(householdId, items);
      }
    }
  }

  Future<void> deleteGoal(String householdId, String goalId) async {
    try {
      await _firestore
          .collection('households')
          .doc(householdId)
          .collection('savings_goals')
          .doc(goalId)
          .delete();
    } catch (_) {
      final items = await _loadFromLocal(householdId);
      items.removeWhere((i) => i.id == goalId);
      await _saveToLocal(householdId, items);
    }
  }

  Future<void> depositToGoal(
    String householdId,
    String goalId,
    double amount,
  ) async {
    if (amount <= 0) return;
    try {
      await _firestore
          .collection('households')
          .doc(householdId)
          .collection('savings_goals')
          .doc(goalId)
          .update({'currentAmount': FieldValue.increment(amount)});
    } catch (_) {
      final items = await _loadFromLocal(householdId);
      final idx = items.indexWhere((i) => i.id == goalId);
      if (idx != -1) {
        items[idx] = items[idx].copyWith(currentAmount: items[idx].currentAmount + amount);
        await _saveToLocal(householdId, items);
      }
    }
  }

  Future<void> withdrawFromGoal(
    String householdId,
    String goalId,
    double amount,
  ) async {
    if (amount <= 0) return;
    try {
      await _firestore
          .collection('households')
          .doc(householdId)
          .collection('savings_goals')
          .doc(goalId)
          .update({'currentAmount': FieldValue.increment(-amount)});
    } catch (_) {
      final items = await _loadFromLocal(householdId);
      final idx = items.indexWhere((i) => i.id == goalId);
      if (idx != -1) {
        final newAmt = (items[idx].currentAmount - amount).clamp(0.0, double.infinity);
        items[idx] = items[idx].copyWith(currentAmount: newAmt);
        await _saveToLocal(householdId, items);
      }
    }
  }
}
