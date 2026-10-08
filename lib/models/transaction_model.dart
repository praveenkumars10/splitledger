import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { paid, received }

enum RecurrenceInterval { none, daily, weekly, biweekly, monthly, yearly }

class TransactionModel {
  final String id;
  final double amount;
  final String category; // Kept for legacy/filtering
  final String paidByUid;
  final String paidByName;
  final String? note;
  final String? receiptUrl;
  final String? counterpartyUid;
  final DateTime date;
  final DateTime? dueDate;
  final TransactionType type;
  final DateTime createdAt;

  /// Optional custom split percentages by member uid (must sum to ~100).
  final Map<String, double>? splitPercentages;

  /// Optional custom split weights by member uid.
  final Map<String, double>? splitShares;

  TransactionModel({
    required this.id,
    required this.amount,
    required this.category,
    required this.paidByUid,
    required this.paidByName,
    this.note,
    this.receiptUrl,
    this.counterpartyUid,
    required this.date,
    this.dueDate,
    this.type = TransactionType.paid,
    required this.createdAt,
    this.splitPercentages,
    this.splitShares,
    this.recurrence = RecurrenceInterval.none,
    this.recurrenceEndDate,
    this.nextOccurrence,
  });

  final RecurrenceInterval recurrence;
  final DateTime? recurrenceEndDate;
  final DateTime? nextOccurrence;

  static DateTime calculateNextOccurrence(DateTime from, RecurrenceInterval interval) {
    switch (interval) {
      case RecurrenceInterval.daily:
        return from.add(const Duration(days: 1));
      case RecurrenceInterval.weekly:
        return from.add(const Duration(days: 7));
      case RecurrenceInterval.biweekly:
        return from.add(const Duration(days: 14));
      case RecurrenceInterval.monthly:
        return DateTime(from.year, from.month + 1, from.day, from.hour, from.minute);
      case RecurrenceInterval.yearly:
        return DateTime(from.year + 1, from.month, from.day, from.hour, from.minute);
      case RecurrenceInterval.none:
        return from;
    }
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map, String id) {
    return TransactionModel(
      id: id,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] ?? 'general',
      paidByUid: map['paidByUid'] ?? '',
      paidByName: map['paidByName'] ?? '',
      note: map['note'],
      receiptUrl: map['receiptUrl'],
      counterpartyUid: map['counterpartyUid'],
      date: (map['date'] as Timestamp).toDate(),
      dueDate: map['dueDate'] != null ? (map['dueDate'] as Timestamp).toDate() : null,
      type: map['type'] == 'received' ? TransactionType.received : TransactionType.paid,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      splitPercentages: (map['splitPercentages'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
      splitShares: (map['splitShares'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
      recurrence: map['recurrence'] != null
          ? RecurrenceInterval.values.firstWhere(
              (e) => e.name == map['recurrence'] || e.toString().split('.').last == map['recurrence'],
              orElse: () => RecurrenceInterval.none,
            )
          : RecurrenceInterval.none,
      recurrenceEndDate: map['recurrenceEndDate'] != null ? (map['recurrenceEndDate'] as Timestamp).toDate() : null,
      nextOccurrence: map['nextOccurrence'] != null ? (map['nextOccurrence'] as Timestamp).toDate() : null,
    );
  }

  TransactionModel copyWith({
    String? id,
    double? amount,
    String? category,
    String? paidByUid,
    String? paidByName,
    String? note,
    String? receiptUrl,
    String? counterpartyUid,
    DateTime? date,
    DateTime? dueDate,
    TransactionType? type,
    DateTime? createdAt,
    Map<String, double>? splitPercentages,
    Map<String, double>? splitShares,
    RecurrenceInterval? recurrence,
    DateTime? recurrenceEndDate,
    DateTime? nextOccurrence,
  }) => TransactionModel(
        id: id ?? this.id,
        amount: amount ?? this.amount,
        category: category ?? this.category,
        paidByUid: paidByUid ?? this.paidByUid,
        paidByName: paidByName ?? this.paidByName,
        note: note ?? this.note,
        receiptUrl: receiptUrl ?? this.receiptUrl,
        counterpartyUid: counterpartyUid ?? this.counterpartyUid,
        date: date ?? this.date,
        dueDate: dueDate ?? this.dueDate,
        type: type ?? this.type,
        createdAt: createdAt ?? this.createdAt,
        splitPercentages: splitPercentages ?? this.splitPercentages,
        splitShares: splitShares ?? this.splitShares,
        recurrence: recurrence ?? this.recurrence,
        recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
        nextOccurrence: nextOccurrence ?? this.nextOccurrence,
      );

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'category': category,
      'paidByUid': paidByUid,
      'paidByName': paidByName,
      'note': note,
      'receiptUrl': receiptUrl,
      'counterpartyUid': counterpartyUid,
      'date': Timestamp.fromDate(date),
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'type': type == TransactionType.received ? 'received' : 'paid',
      'createdAt': Timestamp.fromDate(createdAt),
      'splitPercentages': splitPercentages,
      'splitShares': splitShares,
      'recurrence': recurrence.name,
      'recurrenceEndDate': recurrenceEndDate != null ? Timestamp.fromDate(recurrenceEndDate!) : null,
      'nextOccurrence': nextOccurrence != null ? Timestamp.fromDate(nextOccurrence!) : null,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'paidByUid': paidByUid,
      'paidByName': paidByName,
      'note': note,
      'receiptUrl': receiptUrl,
      'counterpartyUid': counterpartyUid,
      'date': date.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'type': type == TransactionType.received ? 'received' : 'paid',
      'createdAt': createdAt.toIso8601String(),
      'splitPercentages': splitPercentages,
      'splitShares': splitShares,
      'recurrence': recurrence.name,
      'recurrenceEndDate': recurrenceEndDate?.toIso8601String(),
      'nextOccurrence': nextOccurrence?.toIso8601String(),
    };
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return TransactionModel(
      id: json['id'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] ?? 'general',
      paidByUid: json['paidByUid'] ?? '',
      paidByName: json['paidByName'] ?? '',
      note: json['note'],
      receiptUrl: json['receiptUrl'],
      counterpartyUid: json['counterpartyUid'],
      date: parseDate(json['date']),
      dueDate: parseNullableDate(json['dueDate']),
      type: json['type'] == 'received' ? TransactionType.received : TransactionType.paid,
      createdAt: parseDate(json['createdAt']),
      splitPercentages: (json['splitPercentages'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
      splitShares: (json['splitShares'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      ),
      recurrence: json['recurrence'] != null
          ? RecurrenceInterval.values.firstWhere(
              (e) => e.name == json['recurrence'],
              orElse: () => RecurrenceInterval.none,
            )
          : RecurrenceInterval.none,
      recurrenceEndDate: parseNullableDate(json['recurrenceEndDate']),
      nextOccurrence: parseNullableDate(json['nextOccurrence']),
    );
  }
}

