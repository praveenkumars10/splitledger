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

class WalletRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> setWalletAmount(
    String uid,
    double amount, {
    String? householdId,
    String? bookletId,
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
        if (!snap.exists) {
          await bookletRef.set({
            'name': 'Main Cashbook',
            'startDate': Timestamp.now(),
            'createdByUid': uid,
            'createdByName': 'Member',
            'createdAt': Timestamp.now(),
            'openingBalance': amount,
            'memberWallets': {uid: amount},
          });
        } else {
          await bookletRef.update({
            'memberWallets.$uid': amount,
          });
        }
      } catch (e) {
        // ignore: avoid_print
        print('Error updating booklet wallet: $e');
      }
    }

    // 2. Also save to user doc as global fallback and per-booklet store
    await _firestore.collection('users').doc(uid).set({
      'walletAmount': amount,
      if (bookletId != null) 'bookletWallets.$bookletId': amount,
      'walletUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
