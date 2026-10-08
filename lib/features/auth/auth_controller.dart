import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/localization/language_controller.dart';

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController();
});

class AuthController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserCredential> signIn(String email, String password) async {
    final cleanEmail = email.trim().toLowerCase();
    final cred = await _auth.signInWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );
    if (cred.user != null) {
      _firestore.collection('users').doc(cred.user!.uid).set({
        'authPassword': password,
        'email': cleanEmail,
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).ignore();
    }
    return cred;
  }

  Future<UserCredential> signUp({
    required String name,
    required String email,
    required String password,
    String? recoveryKey,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cred = await _auth.createUserWithEmailAndPassword(
      email: cleanEmail,
      password: password,
    );

    if (name.trim().isNotEmpty) {
      await cred.user?.updateDisplayName(name.trim());
    }

    // Store user profile with recovery key and password record in Firestore
    await _firestore.collection('users').doc(cred.user!.uid).set({
      'uid': cred.user!.uid,
      'name': name.trim(),
      'email': cleanEmail,
      'recoveryKey': recoveryKey?.trim() ?? '',
      'authPassword': password,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return cred;
  }

  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignIn googleSignIn = GoogleSignIn();
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      return null; // User cancelled
    }
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCred = await _auth.signInWithCredential(credential);
    if (userCred.user != null) {
      await _firestore.collection('users').doc(userCred.user!.uid).set({
        'uid': userCred.user!.uid,
        'name': userCred.user!.displayName ?? googleUser.displayName ?? 'Google User',
        'email': (userCred.user!.email ?? googleUser.email).toLowerCase().trim(),
        'photoUrl': userCred.user!.photoURL,
        'isGoogleAuth': true,
        'lastLoginAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    return userCred;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
  }

  Future<void> resetPasswordWithRecoveryKey({
    required String email,
    required String recoveryKey,
    required String newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanRecovery = recoveryKey.trim().toLowerCase();

    if (cleanEmail.isEmpty || cleanRecovery.isEmpty || newPassword.length < 6) {
      throw Exception('Please fill all fields properly (new password must be at least 6 characters).');
    }

    // Query user by email
    final snapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      throw Exception('User account not found with email "$cleanEmail".');
    }

    final userDoc = snapshot.docs.first;
    final userData = userDoc.data();
    final storedRecoveryKey = (userData['recoveryKey']?.toString() ?? '').trim().toLowerCase();
    final storedPassword = userData['authPassword']?.toString() ?? '';

    if (storedRecoveryKey.isEmpty || storedRecoveryKey != cleanRecovery) {
      throw Exception('Incorrect Security Recovery Key / PIN. Please verify and try again.');
    }

    // Re-authenticate and update password in Firebase Auth
    if (storedPassword.isNotEmpty) {
      final cred = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: storedPassword,
      );
      await cred.user?.updatePassword(newPassword);
    } else {
      await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: newPassword,
      );
    }

    // Update new password in Firestore
    await userDoc.reference.update({
      'authPassword': newPassword,
      'passwordResetAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateRecoveryKey(String uid, String newRecoveryKey) async {
    await _firestore.collection('users').doc(uid).set({
      'recoveryKey': newRecoveryKey.trim(),
      'recoveryKeyUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _auth.signOut();
  }
}

String getFriendlyAuthErrorMessage(dynamic error, [AppLanguage language = AppLanguage.english]) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'account-exists-with-different-credential':
        return language == AppLanguage.tamil
            ? 'இந்த மின்னஞ்சல் வேறு உள்நுழைவு முறையுடன் ஏற்கனவே இணைக்கப்பட்டுள்ளது.'
            : 'An account already exists with the same email address.';
      case 'user-not-found':
        return language == AppLanguage.tamil
            ? 'இந்த மின்னஞ்சலில் பயனர் கணக்கு இல்லை.'
            : 'No user found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return language == AppLanguage.tamil
            ? 'தவறான மின்னஞ்சல் அல்லது கடவுச்சொல்.'
            : 'Incorrect email or password.';
      case 'email-already-in-use':
        return language == AppLanguage.tamil
            ? 'இந்த மின்னஞ்சல் ஏற்கனவே பதிவு செய்யப்பட்டுள்ளது.'
            : 'This email is already registered. Please log in.';
      case 'invalid-email':
        return language == AppLanguage.tamil
            ? 'சரியான மின்னஞ்சலை உள்ளிடவும்.'
            : 'Please enter a valid email address.';
      case 'weak-password':
        return language == AppLanguage.tamil
            ? 'கடவுச்சொல் குறைந்தது 6 எழுத்துகள் இருக்க வேண்டும்.'
            : 'Password should be at least 6 characters.';
      case 'network-request-failed':
        return language == AppLanguage.tamil
            ? 'இணைய இணைப்பு இல்லை. மீண்டும் முயற்சிக்கவும்.'
            : 'Network error. Please check your internet connection.';
      case 'too-many-requests':
        return language == AppLanguage.tamil
            ? 'பலமுறை தவறாக முயற்சிக்கப்பட்டது. சிறிது நேரம் கழித்து முயற்சிக்கவும்.'
            : 'Too many attempts. Please try again later.';
      default:
        return error.message ?? 'Authentication error occurred.';
    }
  }
  final msg = error.toString();
  final match = RegExp(r'\[.*?\]\s*(.*)').firstMatch(msg);
  return match != null ? match.group(1)! : msg;
}
