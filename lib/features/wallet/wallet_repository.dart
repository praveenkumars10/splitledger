import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_controller.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository();
});

final currentWalletAmountProvider = StreamProvider<double>((ref) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return Stream.value(0.0);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((snapshot) {
        if (!snapshot.exists) return 0.0;
        final data = snapshot.data();
        final raw = data?['walletAmount'];
        if (raw is num) return raw.toDouble();
        return 0.0;
      });
});

/// Stream of user's booklet-specific wallets: { 'bookletId': amount, ... }
final userBookletWalletsProvider = StreamProvider<Map<String, double>>((ref) {
  final user = ref.watch(authStateChangesProvider).asData?.value;
  if (user == null) return Stream.value({});

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((snapshot) {
        if (!snapshot.exists) return {};
        final data = snapshot.data();
        final raw = data?['bookletWallets'];
        if (raw is Map) {
          return raw.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
        }
        return {};
      });
});

class WalletRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> setWalletAmount(
    String uid,
    double amount, {
    String? householdId,
    String? bookletId,
    String? userName,
  }) async {
    // 1. If cashbook context is present, save under the specific cashbook document
    if (householdId != null && bookletId != null && bookletId.isNotEmpty) {
      final bookletRef = _firestore
          .collection('households')
          .doc(householdId)
          .collection('booklets')
          .doc(bookletId);

      try {
        final snap = await bookletRef.get();
        final existingData = snap.data() ?? {};
        final rawWallets = existingData['memberWallets'];
        final Map<String, dynamic> wallets = rawWallets is Map
            ? Map<String, dynamic>.from(rawWallets)
            : {};
        wallets[uid] = amount;

        if (!snap.exists) {
          await bookletRef.set({
            'name': 'Cashbook 1',
            'startDate': Timestamp.now(),
            'createdByUid': uid,
            'createdByName': userName ?? 'Member',
            'createdAt': Timestamp.now(),
            'openingBalance': amount,
            'memberWallets': wallets,
          });
        } else {
          await bookletRef.set({
            'memberWallets': wallets,
          }, SetOptions(merge: true));
        }
      } catch (e) {
        // ignore: avoid_print
        print('Error updating booklet wallet in bookletRef: $e');
      }

      // 2. Save under user doc specifically for this booklet (isolated per booklet)
      try {
        await _firestore.collection('users').doc(uid).set({
          'bookletWallets': {
            bookletId: amount,
          },
          'walletUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}

      // 3. Create or update the Wallet Incoming transaction entry (Bank passbook style!)
      try {
        await ensureWalletTransaction(
          householdId: householdId,
          bookletId: bookletId,
          uid: uid,
          amount: amount,
          userName: userName,
        );
      } catch (e) {
        // ignore: avoid_print
        print('Error ensuring wallet transaction: $e');
      }
    } else {
      // Fallback/standalone global wallet
      await _firestore.collection('users').doc(uid).set({
        'walletAmount': amount,
        'walletUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  /// Ensures an incoming transaction entry exists for the wallet amount (Bank Passbook credit entry).
  /// Uses a deterministic document ID (`wallet_${bookletId}_${uid}`) and cleans up any duplicates.
  Future<void> ensureWalletTransaction({
    required String householdId,
    required String bookletId,
    required String uid,
    required double amount,
    String? userName,
  }) async {
    final txCollection = _firestore
        .collection('households')
        .doc(householdId)
        .collection('transactions');

    final deterministicDocId = 'wallet_${bookletId}_$uid';
    final targetDocRef = txCollection.doc(deterministicDocId);

    // 1. Query any duplicate or legacy wallet transactions for this booklet and member
    try {
      final existingSnap = await txCollection
          .where('bookletId', isEqualTo: bookletId)
          .where('paidByUid', isEqualTo: uid)
          .where('category', isEqualTo: 'wallet')
          .get();

      // Delete any duplicates or old random-ID docs
      for (final doc in existingSnap.docs) {
        if (doc.id != deterministicDocId) {
          try {
            await doc.reference.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}

    if (amount > 0) {
      // 2. Always write to the deterministic single document ID (idempotent)!
      await targetDocRef.set({
        'amount': amount,
        'category': 'wallet',
        'paidByUid': uid,
        'paidByName': userName ?? 'Member',
        'note': 'Wallet Deposit',
        'type': 'received',
        'date': Timestamp.now(),
        'createdAt': Timestamp.now(),
        'bookletId': bookletId,
      }, SetOptions(merge: true));
    } else {
      // If amount is 0, delete the deterministic doc too
      try {
        await targetDocRef.delete();
      } catch (_) {}
    }
  }
}
