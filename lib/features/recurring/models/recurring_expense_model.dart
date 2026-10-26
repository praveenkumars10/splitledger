class RecurringExpenseModel {
  final String id;
  final String householdId;
  final String title;
  final double amount;
  final String category;
  final int dueDay; // 1 to 31
  final String paidByUid;
  final String paidByName;
  final String? notes;
  final bool isActive;
  final String? lastLoggedCycle; // e.g. "2026-10"
  final DateTime createdAt;

  const RecurringExpenseModel({
    required this.id,
    required this.householdId,
    required this.title,
    required this.amount,
    required this.category,
    required this.dueDay,
    required this.paidByUid,
    required this.paidByName,
    this.notes,
    this.isActive = true,
    this.lastLoggedCycle,
    required this.createdAt,
  });

  bool isLoggedForCycle(String cycleKey) {
    return lastLoggedCycle == cycleKey;
  }

  /// Calculates days until the next occurrence from a reference date
  int daysUntilDue(DateTime now) {
    final clampedDay = dueDay.clamp(1, 28); // safe day clamp
    var target = DateTime(now.year, now.month, clampedDay);
    if (target.isBefore(DateTime(now.year, now.month, now.day))) {
      target = DateTime(now.year, now.month + 1, clampedDay);
    }
    return target.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  bool isDueSoon(DateTime now, {int thresholdDays = 3}) {
    final diff = daysUntilDue(now);
    return diff >= 0 && diff <= thresholdDays;
  }

  bool isDueToday(DateTime now) {
    return daysUntilDue(now) == 0;
  }

  RecurringExpenseModel copyWith({
    String? id,
    String? householdId,
    String? title,
    double? amount,
    String? category,
    int? dueDay,
    String? paidByUid,
    String? paidByName,
    String? notes,
    bool? isActive,
    String? lastLoggedCycle,
    DateTime? createdAt,
  }) {
    return RecurringExpenseModel(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      dueDay: dueDay ?? this.dueDay,
      paidByUid: paidByUid ?? this.paidByUid,
      paidByName: paidByName ?? this.paidByName,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      lastLoggedCycle: lastLoggedCycle ?? this.lastLoggedCycle,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'householdId': householdId,
      'title': title,
      'amount': amount,
      'category': category,
      'dueDay': dueDay,
      'paidByUid': paidByUid,
      'paidByName': paidByName,
      'notes': notes,
      'isActive': isActive,
      'lastLoggedCycle': lastLoggedCycle,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory RecurringExpenseModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    return RecurringExpenseModel(
      id: docId ?? map['id'] as String? ?? '',
      householdId: map['householdId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] as String? ?? 'bills',
      dueDay: (map['dueDay'] as num?)?.toInt() ?? 1,
      paidByUid: map['paidByUid'] as String? ?? '',
      paidByName: map['paidByName'] as String? ?? 'Member',
      notes: map['notes'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      lastLoggedCycle: map['lastLoggedCycle'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
