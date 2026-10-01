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

  Future<void> setWalletAmount(String uid, double amount) async {
    await _firestore.collection('users').doc(uid).set({
      'walletAmount': amount,
      'walletUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
