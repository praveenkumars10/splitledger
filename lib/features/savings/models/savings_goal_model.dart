class SavingsGoalModel {
  final String id;
  final String householdId;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final DateTime? targetDate;
  final String emoji;
  final int colorValue;
  final String? notes;
  final DateTime createdAt;

  const SavingsGoalModel({
    required this.id,
    required this.householdId,
    required this.title,
    required this.targetAmount,
    this.currentAmount = 0.0,
    this.targetDate,
    this.emoji = '🎯',
    this.colorValue = 0xFF10B981,
    this.notes,
    required this.createdAt,
  });

  double get remainingAmount =>
      (targetAmount - currentAmount).clamp(0.0, targetAmount);

  double get percentage =>
      targetAmount > 0 ? (currentAmount / targetAmount) * 100 : 0.0;

  double get progressRatio =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

  bool get isCompleted => currentAmount >= targetAmount;

  SavingsGoalModel copyWith({
    String? id,
    String? householdId,
    String? title,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    String? emoji,
    int? colorValue,
    String? notes,
    DateTime? createdAt,
  }) {
    return SavingsGoalModel(
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      emoji: emoji ?? this.emoji,
      colorValue: colorValue ?? this.colorValue,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'householdId': householdId,
      'title': title,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'targetDate': targetDate?.toIso8601String(),
      'emoji': emoji,
      'colorValue': colorValue,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SavingsGoalModel.fromMap(Map<String, dynamic> map, {String? docId}) {
    return SavingsGoalModel(
      id: docId ?? map['id'] as String? ?? '',
      householdId: map['householdId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      targetAmount: (map['targetAmount'] as num?)?.toDouble() ?? 0.0,
      currentAmount: (map['currentAmount'] as num?)?.toDouble() ?? 0.0,
      targetDate: map['targetDate'] != null
          ? DateTime.tryParse(map['targetDate'] as String)
          : null,
      emoji: map['emoji'] as String? ?? '🎯',
      colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFF10B981,
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
