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
    final query = await _firestore.collection('households')
        .where('inviteCode', isEqualTo: inviteCode)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Invalid invite code');
    }

    final doc = query.docs.first;
    final household = Household.fromMap(doc.data(), doc.id);



    if (household.members.any((m) => m.uid == uid)) {
      throw Exception('You are already in this household');
    }

    final newMember = HouseholdMember(uid: uid, name: userName);
    final updatedMembers = [...household.members, newMember];

    await doc.reference.update({
      'members': updatedMembers.map((m) => m.toMap()).toList(),
      'memberUids': updatedMembers.map((m) => m.uid).toList(),
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
    return _firestore.collection('households')
        // Firestore arrays with maps can't be queried with arrayContains cleanly unless it's exactly the same map
        // As a workaround, we listen to all households this user is in by keeping a flat array of UIDs or doing it client side.
        // For our scale, we'll listen to households where uid is present (we need to change model to support this, or query all and filter).
        // Best practice: add an array 'memberIds' for querying.
        // Let's assume memberIds is not there, we'll query and map on client for this demo, or we'll update the create/join to include memberIds.
        .snapshots()
        .map((snapshot) {
          try {
            final doc = snapshot.docs.firstWhere(
              (d) {
                final members = d.data()['members'] as List<dynamic>? ?? [];
                return members.any((m) => m['uid'] == uid);
              }
            );
            return Household.fromMap(doc.data(), doc.id);
          } catch (e) {
            return null;
          }
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
    
    await doc.reference.update({
      'members': updatedMembers.map((m) => m.toMap()).toList(),
      'memberUids': updatedMembers.map((m) => m.uid).toList(),
    });
  }
}
