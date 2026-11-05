import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/booklet_model.dart';
import '../../models/transaction_model.dart';
import '../../models/deleted_audit_item_model.dart';
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

  void setFilter(String? value) {
    if (value == 'ALL') {
      state = null; // 'ALL' removed, reset to active booklet
    } else {
      state = value;
    }
  }
}

/// Locally selected booklet filter override (null for active, or a specific bookletId).
final selectedBookletFilterProvider = NotifierProvider<SelectedBookletFilterNotifier, String?>(() {
  return SelectedBookletFilterNotifier();
});

/// Resolves the current active or selected BookletModel.
final activeBookletProvider = Provider<BookletModel?>((ref) {
  final filter = ref.watch(selectedBookletFilterProvider);

  final booklets = ref.watch(bookletsStreamProvider).asData?.value ?? [];
  final household = ref.watch(currentHouseholdProvider).asData?.value;
  final preferences = ref.watch(appPreferencesProvider);

  // 1. If explicit specific ID selected
  if (filter != null && filter.isNotEmpty && filter != 'ALL') {
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
final activeBookletTransactionsProvider = Provider<List<TransactionModel>>((ref) {
  final allTx = ref.watch(currentTransactionsProvider).asData?.value ?? [];
  final activeBooklet = ref.watch(activeBookletProvider);
  if (activeBooklet == null) return allTx;

  final booklets = ref.watch(bookletsStreamProvider).asData?.value ?? [];
  final isDefaultOrOnly = activeBooklet.id == 'default' || booklets.isEmpty || (booklets.length == 1 && booklets.first.id == activeBooklet.id);

  return allTx.where((tx) {
    if (tx.bookletId == activeBooklet.id) return true;
    // Allow legacy / untagged transactions or if single cashbook active
    if (tx.bookletId == null) return true;
    if (isDefaultOrOnly) return true;
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
      memberWallets: openingBalance > 0 ? {createdByUid: openingBalance} : {},
    );

    final batch = _firestore.batch();
    batch.set(docRef, booklet.toMap());
    batch.update(_firestore.collection('households').doc(householdId), {
      'activeBookletId': booklet.id,
    });
    await batch.commit();

    if (openingBalance > 0 && createdByUid.isNotEmpty) {
      try {
        await _firestore.collection('users').doc(createdByUid).set({
          'bookletWallets': {
            booklet.id: openingBalance,
          },
          'walletUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
    }

    return booklet;
  }

  Future<void> setMemberWallet({
    required String householdId,
    required String bookletId,
    required String uid,
    required double amount,
  }) async {
    final docRef = _firestore
        .collection('households')
        .doc(householdId)
        .collection('booklets')
        .doc(bookletId);

    try {
      final snap = await docRef.get();
      final existingData = snap.data() ?? {};
      final rawWallets = existingData['memberWallets'];
      final Map<String, dynamic> wallets = rawWallets is Map
          ? Map<String, dynamic>.from(rawWallets)
          : {};
      wallets[uid] = amount;

      if (!snap.exists) {
        await docRef.set({
          'name': 'Main Cashbook',
          'startDate': Timestamp.now(),
          'createdByUid': uid,
          'createdByName': 'Member',
          'createdAt': Timestamp.now(),
          'openingBalance': amount,
          'memberWallets': wallets,
        });
      } else {
        await docRef.set({
          'memberWallets': wallets,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error updating booklet memberWallets: $e');
    }

    try {
      await _firestore.collection('users').doc(uid).set({
        'bookletWallets': {
          bookletId: amount,
        },
        'walletUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
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

  Future<void> deleteBooklet({
    required String householdId,
    required String bookletId,
    bool deleteAssociatedTransactions = true,
    String? deletedByUid,
    String? deletedByName,
    BookletModel? bookletData,
  }) async {
    final bookletDoc = _firestore
        .collection('households')
        .doc(householdId)
        .collection('booklets')
        .doc(bookletId);

    // 1. Fetch booklet data if not provided
    BookletModel? booklet = bookletData;
    if (booklet == null) {
      try {
        final bSnap = await bookletDoc.get();
        if (bSnap.exists && bSnap.data() != null) {
          booklet = BookletModel.fromMap(bSnap.data()!, bSnap.id);
        }
      } catch (_) {}
    }
    final bookletName = booklet?.name ?? 'Cashbook';

    // 2. Gather all transactions in this booklet
    final txSnapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('transactions')
        .where('bookletId', isEqualTo: bookletId)
        .get();

    final List<TransactionModel> transactions = [];
    double totalAmount = 0.0;
    for (final doc in txSnapshot.docs) {
      final tx = TransactionModel.fromMap(doc.data(), doc.id);
      transactions.add(tx);
      totalAmount += tx.amount;
    }

    // 3. Record booklet deletion in immutable audit log
    if (booklet != null) {
      try {
        final auditRef = _firestore
            .collection('households')
            .doc(householdId)
            .collection('deleted_history')
            .doc();

        final auditItem = DeletedAuditItemModel.fromBooklet(
          id: auditRef.id,
          booklet: booklet,
          deletedByUid: deletedByUid ?? '',
          deletedByName: (deletedByName != null && deletedByName.trim().isNotEmpty)
              ? deletedByName
              : 'Member',
          transactionCount: transactions.length,
          totalAmount: totalAmount,
        );

        await auditRef.set(auditItem.toMap());
      } catch (e) {
        // ignore: avoid_print
        print('Failed to record booklet deletion audit log: $e');
      }
    }

    // 4. If deleting associated transactions, record each in audit log
    if (deleteAssociatedTransactions && transactions.isNotEmpty) {
      try {
        final now = DateTime.now();
        for (final tx in transactions) {
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
            deletedAt: now,
          );

          await auditRef.set(auditItem.toMap());
        }
      } catch (e) {
        // ignore: avoid_print
        print('Failed to record deleted transactions audit log: $e');
      }
    }

    // 5. Delete booklet and delete/untag transactions
    final List<DocumentReference> toDelete = [bookletDoc];
    final List<DocumentReference> toUntag = [];

    for (final doc in txSnapshot.docs) {
      if (deleteAssociatedTransactions) {
        toDelete.add(doc.reference);
      } else {
        toUntag.add(doc.reference);
      }
    }

    WriteBatch batch = _firestore.batch();
    int opCount = 0;

    // Clear household activeBookletId if it points to the deleted booklet
    final householdRef = _firestore.collection('households').doc(householdId);
    try {
      final householdDoc = await householdRef.get();
      if (householdDoc.data()?['activeBookletId'] == bookletId) {
        batch.update(householdRef, {'activeBookletId': null});
        opCount++;
      }
    } catch (_) {}

    for (final ref in toDelete) {
      batch.delete(ref);
      opCount++;
      if (opCount >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        opCount = 0;
      }
    }

    for (final ref in toUntag) {
      batch.update(ref, {'bookletId': null});
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

  /// Transfers/migrates all household transactions to a specific target booklet.
  Future<int> transferAllTransactionsToBooklet({
    required String householdId,
    required String targetBookletId,
  }) async {
    final snapshot = await _firestore
        .collection('households')
        .doc(householdId)
        .collection('transactions')
        .get();

    WriteBatch batch = _firestore.batch();
    int transferredCount = 0;
    int batchOps = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final currentBookletId = data['bookletId'];
      if (currentBookletId != targetBookletId) {
        batch.update(doc.reference, {'bookletId': targetBookletId});
        transferredCount++;
        batchOps++;
        if (batchOps >= 400) {
          await batch.commit();
          batch = _firestore.batch();
          batchOps = 0;
        }
      }
    }

    if (batchOps > 0) {
      await batch.commit();
    }

    return transferredCount;
  }
}
