import 'package:cloud_firestore/cloud_firestore.dart';

class BookletModel {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isClosed;
  final double openingBalance;
  final String createdByUid;
  final String createdByName;
  final DateTime createdAt;
  final String? note;

  /// Member-specific wallet amounts for this cashbook: { 'uid1': 2000.0, 'uid2': 2000.0 }
  final Map<String, double> memberWallets;

  const BookletModel({
    required this.id,
    required this.name,
    required this.startDate,
    this.endDate,
    this.isClosed = false,
    this.openingBalance = 0.0,
    required this.createdByUid,
    required this.createdByName,
    required this.createdAt,
    this.note,
    this.memberWallets = const {},
  });

  /// Total combined wallet budget in this cashbook across all members
  double getTotalWalletAmount({Map<String, double>? userBookletWallets, String? currentUid}) {
    if (memberWallets.isNotEmpty) {
      return memberWallets.values.fold(0.0, (acc, val) => acc + val);
    }
    if (currentUid != null && userBookletWallets != null && userBookletWallets.containsKey(id)) {
      return userBookletWallets[id]!;
    }
    return openingBalance;
  }

  /// Total combined wallet budget in this cashbook across all members (getter)
  double get totalWalletAmount => getTotalWalletAmount();

  /// Get a specific member's wallet amount for this cashbook
  double getMemberWallet(String uid, {Map<String, double>? userBookletWallets}) {
    if (memberWallets.containsKey(uid)) {
      return memberWallets[uid]!;
    }
    if (userBookletWallets != null && userBookletWallets.containsKey(id)) {
      return userBookletWallets[id]!;
    }
    if (uid == createdByUid && openingBalance > 0) {
      return openingBalance;
    }
    return 0.0;
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'isClosed': isClosed,
      'openingBalance': openingBalance,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'note': note,
      'memberWallets': memberWallets,
    };
  }

  factory BookletModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val, {DateTime? fallback}) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? fallback ?? DateTime.now();
      return fallback ?? DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    Map<String, double> parseMemberWallets(dynamic val) {
      if (val is Map) {
        return val.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
      }
      return {};
    }

    return BookletModel(
      id: id,
      name: map['name'] ?? 'General Cashbook',
      startDate: parseDate(map['startDate']),
      endDate: parseNullableDate(map['endDate']),
      isClosed: map['isClosed'] ?? false,
      openingBalance: (map['openingBalance'] as num?)?.toDouble() ?? 0.0,
      createdByUid: map['createdByUid'] ?? '',
      createdByName: map['createdByName'] ?? '',
      createdAt: parseDate(map['createdAt']),
      note: map['note'],
      memberWallets: parseMemberWallets(map['memberWallets']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isClosed': isClosed,
      'openingBalance': openingBalance,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdAt': createdAt.toIso8601String(),
      'note': note,
      'memberWallets': memberWallets,
    };
  }

  factory BookletModel.fromJson(Map<String, dynamic> json) {
    Map<String, double> parseMemberWallets(dynamic val) {
      if (val is Map) {
        return val.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
      }
      return {};
    }

    return BookletModel(
      id: json['id'] ?? '',
      name: json['name'] ?? 'General Cashbook',
      startDate: DateTime.tryParse(json['startDate'] ?? '') ?? DateTime.now(),
      endDate: json['endDate'] != null ? DateTime.tryParse(json['endDate']) : null,
      isClosed: json['isClosed'] ?? false,
      openingBalance: (json['openingBalance'] as num?)?.toDouble() ?? 0.0,
      createdByUid: json['createdByUid'] ?? '',
      createdByName: json['createdByName'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      note: json['note'],
      memberWallets: parseMemberWallets(json['memberWallets']),
    );
  }

  BookletModel copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    bool? isClosed,
    double? openingBalance,
    String? createdByUid,
    String? createdByName,
    DateTime? createdAt,
    String? note,
    Map<String, double>? memberWallets,
  }) {
    return BookletModel(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isClosed: isClosed ?? this.isClosed,
      openingBalance: openingBalance ?? this.openingBalance,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      note: note ?? this.note,
      memberWallets: memberWallets ?? this.memberWallets,
    );
  }
}
