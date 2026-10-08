import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/household_model.dart';
import 'dart:math';

final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  return HouseholdRepository();
});

class HouseholdRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  Future<Household> createHousehold(String uid, String userName) async {
    final inviteCode = _generateInviteCode();
    
    final householdRef = _firestore.collection('households').doc();
    final household = Household(
      id: householdRef.id,
      name: 'Household',
      members: [HouseholdMember(uid: uid, name: userName)],
      createdAt: DateTime.now(),
      inviteCode: inviteCode,
    );

    await householdRef.set(household.toMap());
    return household;
  }

  Future<Household> joinHousehold(String inviteCode, String uid, String userName) async {
    final cleanCode = inviteCode.trim().toUpperCase();
    final query = await _firestore.collection('households')
        .where('inviteCode', isEqualTo: cleanCode)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Invalid invite code. Please check and try again.');
    }

    final doc = query.docs.first;
    final data = doc.data();
    final household = Household.fromMap(data, doc.id);

    // If the user is already a member, ensure memberUids is updated and let them in smoothly
    if (household.members.any((m) => m.uid == uid)) {
      final allMemberUids = household.members.map((m) => m.uid).toSet()..add(uid);
      await doc.reference.update({
        'memberUids': allMemberUids.toList(),
      });
      return household;
    }

    final newMember = HouseholdMember(uid: uid, name: userName);
    final updatedMembers = [...household.members, newMember];
    final allMemberUids = updatedMembers.map((m) => m.uid).toSet().toList();

    await doc.reference.update({
      'members': updatedMembers.map((m) => m.toMap()).toList(),
      'memberUids': allMemberUids,
    });

    return Household(
      id: household.id,
      name: household.name,
      members: updatedMembers,
      createdAt: household.createdAt,
      inviteCode: household.inviteCode,
    );
  }

  Stream<Household?> watchUserHousehold(String uid) {
    return _firestore
        .collection('households')
        .snapshots()
        .map((snapshot) {
          for (final doc in snapshot.docs) {
            final data = doc.data();
            
            // Check modern memberUids array
            final memberUids = (data['memberUids'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList();
            if (memberUids != null && memberUids.contains(uid)) {
              return Household.fromMap(data, doc.id);
            }

            // Fallback & automatic migration for legacy documents with only 'members' array
            final members = (data['members'] as List<dynamic>?) ?? [];
            for (final m in members) {
              if (m is Map && (m['uid'] == uid || m['uid']?.toString() == uid)) {
                final allUids = members
                    .map((e) => e is Map ? e['uid']?.toString() : null)
                    .whereType<String>()
                    .toList();
                // Backfill memberUids so future queries are instant
                doc.reference.update({
                  'memberUids': allUids,
                }).catchError((_) {});
                return Household.fromMap(data, doc.id);
              }
            }
          }
          return null;
        });
  }

  Future<void> updateHouseholdName(String householdId, String newName) async {
    await _firestore.collection('households').doc(householdId).update({
      'name': newName,
    });
  }

  Future<void> leaveHousehold(String householdId, String uid) async {
    final doc = await _firestore.collection('households').doc(householdId).get();
    if (!doc.exists) return;
    
    final household = Household.fromMap(doc.data()!, doc.id);
    final updatedMembers = household.members.where((m) => m.uid != uid).toList();
    final allMemberUids = updatedMembers.map((m) => m.uid).toList();
    
    await doc.reference.update({
      'members': updatedMembers.map((m) => m.toMap()).toList(),
      'memberUids': allMemberUids,
    });
  }
}
