import 'package:cloud_firestore/cloud_firestore.dart';

class HouseholdMember {
  final String uid;
  final String name;

  HouseholdMember({
    required this.uid,
    required this.name,
  });

  factory HouseholdMember.fromMap(Map<String, dynamic> map) {
    return HouseholdMember(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
    };
  }
}

class Household {
  final String id;
  final String name;
  final List<HouseholdMember> members;
  final DateTime createdAt;
  final String inviteCode;

  Household({
    required this.id,
    required this.name,
    required this.members,
    required this.createdAt,
    required this.inviteCode,
  });

  factory Household.fromMap(Map<String, dynamic> map, String id) {
    return Household(
      id: id,
      name: map['name'] ?? 'Household',
      members: (map['members'] as List<dynamic>? ?? [])
          .map((e) => HouseholdMember.fromMap(e as Map<String, dynamic>))
          .toList(),
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : DateTime.now(),
      inviteCode: map['inviteCode'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'members': members.map((e) => e.toMap()).toList(),
      'memberUids': members.map((e) => e.uid).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'inviteCode': inviteCode,
    };
  }
}
