import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/booklet_model.dart';
import '../../models/transaction_model.dart';
import '../household/current_household_provider.dart';
import '../../core/preferences/app_preferences.dart';
import '../transactions/transaction_repository.dart';

final bookletRepositoryProvider = Provider<BookletRepository>((ref) {
  return BookletRepository();
});

/// Stream of all booklets for the currently active household.
final bookletsStreamProvider = StreamProvider<List<BookletModel>>((ref) {
  final household = ref.watch(currentHouseholdProvider).asData?.value;
  if (household == null) return Stream.value([]);
  return ref.watch(bookletRepositoryProvider).watchBooklets(household.id);
});

class SelectedBookletFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setFilter(String? value) => state = value;
}

/// Locally selected booklet filter override ('ALL', null for active, or a specific bookletId).
final selectedBookletFilterProvider = NotifierProvider<SelectedBookletFilterNotifier, String?>(() {
  return SelectedBookletFilterNotifier();
});

/// Resolves the current active or selected BookletModel.
/// Returns null if 'ALL' is selected.
final activeBookletProvider = Provider<BookletModel?>((ref) {
  final filter = ref.watch(selectedBookletFilterProvider);
  if (filter == 'ALL') return null;

  final booklets = ref.watch(bookletsStreamProvider).asData?.value ?? [];
  final household = ref.watch(currentHouseholdProvider).asData?.value;
  final preferences = ref.watch(appPreferencesProvider);

  // 1. If explicit specific ID selected
  if (filter != null && filter.isNotEmpty) {
    for (final b in booklets) {
      if (b.id == filter) return b;
    }
  }

  // 2. Household's saved activeBookletId
  if (household?.activeBookletId != null) {
    for (final b in booklets) {
      if (b.id == household!.activeBookletId) return b;
    }
  }

  // 3. User local preferences activeBookletId
  if (preferences.activeBookletId != null) {
    for (final b in booklets) {
      if (b.id == preferences.activeBookletId) return b;
    }
  }

  // 4. Return the first non-closed booklet or first booklet
  if (booklets.isNotEmpty) {
    return booklets.firstWhere((b) => !b.isClosed, orElse: () => booklets.first);
  }

  // 5. Default virtual fallback if no booklets are created yet
  return BookletModel(
    id: 'default',
    name: 'Main Cashbook',
    startDate: household?.createdAt ?? DateTime.now(),
    createdByUid: '',
    createdByName: 'System',
    createdAt: household?.createdAt ?? DateTime.now(),
  );
});

/// Returns all transactions belonging to the currently active or selected booklet.
/// If 'ALL' is selected, returns all household transactions.
final activeBookletTransactionsProvider = Provider<List<TransactionModel>>((ref) {
  final allTx = ref.watch(currentTransactionsProvider).asData?.value ?? [];
  final filter = ref.watch(selectedBookletFilterProvider);
  if (filter == 'ALL') {
    return allTx;
  }

  final activeBooklet = ref.watch(activeBookletProvider);
  if (activeBooklet == null) return allTx;

  final booklets = ref.watch(bookletsStreamProvider).asData?.value ?? [];
  final isDefaultOrOnly = activeBooklet.id == 'default' || booklets.isEmpty || (booklets.length == 1 && booklets.first.id == activeBooklet.id);

  return allTx.where((tx) {
    if (tx.bookletId == activeBooklet.id) return true;
    // Allow legacy / untagged transactions in default or only booklet
    if (tx.bookletId == null && isDefaultOrOnly) return true;
    return false;
  }).toList();
});

class BookletRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<BookletModel>> watchBooklets(String householdId) {
    return _firestore
        .collection('households')
        .doc(householdId)
        .collection('booklets')
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => BookletModel.fromMap(doc.data(), doc.id)).toList();
      list.sort((a, b) => b.startDate.compareTo(a.startDate));
      return list;
    });
  }

  Future<BookletModel> createBooklet({
    required String householdId,
    required String name,
    required DateTime startDate,
    required String createdByUid,
    required String createdByName,
    double openingBalance = 0.0,
    String? note,
  }) async {
    final docRef = _firestore
        .collection('households')
        .doc(householdId)
        .collection('booklets')
        .doc();

    final booklet = BookletModel(
      id: docRef.id,
      name: name.trim().isEmpty ? 'Cashbook' : name.trim(),
      startDate: startDate,
      openingBalance: openingBalance,
      createdByUid: createdByUid,
      createdByName: createdByName,
      createdAt: DateTime.now(),
      note: note,
    );

    final batch = _firestore.batch();
    batch.set(docRef, booklet.toMap());
    batch.update(_firestore.collection('households').doc(householdId), {
      'activeBookletId': booklet.id,
    });
    await batch.commit();

    return booklet;
  }

  Future<void> setActiveBooklet(String householdId, String bookletId) async {
    await _firestore.collection('households').doc(householdId).update({
      'activeBookletId': bookletId,
    });
  }

  Future<void> closeBooklet(String householdId, String bookletId) async {
    await _firestore
        .collection('households')
        .doc(householdId)
        .collection('booklets')
        .doc(bookletId)
        .update({
      'isClosed': true,
      'endDate': Timestamp.now(),
    });
  }

  Future<void> reopenBooklet(String householdId, String bookletId) async {
    await _firestore
        .collection('households')
        .doc(householdId)
        .collection('booklets')
        .doc(bookletId)
        .update({
      'isClosed': false,
      'endDate': null,
    });
  }

  Future<void> deleteBooklet(String householdId, String bookletId) async {
    await _firestore
        .collection('households')
        .doc(householdId)
        .collection('booklets')
        .doc(bookletId)
        .delete();
  }
}
