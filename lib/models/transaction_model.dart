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

  factory TransactionModel.fromMap(Map<String, dynamic> map, String id) {
    return TransactionModel(
      id: id,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] ?? 'general',
      paidByUid: map['paidByUid'] ?? '',
      paidByName: map['paidByName'] ?? '',
      note: map['note'],
      receiptUrl: map['receiptUrl'],
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
      recurrence: map['recurrence'] != null ? RecurrenceInterval.values.firstWhere((e) => e.toString().split('.').last == map['recurrence']) : RecurrenceInterval.none,
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
      'date': Timestamp.fromDate(date),
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'type': type == TransactionType.received ? 'received' : 'paid',
      'createdAt': Timestamp.fromDate(createdAt),
      'splitPercentages': splitPercentages,
      'splitShares': splitShares,
      'recurrence': recurrence.toString().split('.').last,
      'recurrenceEndDate': recurrenceEndDate != null ? Timestamp.fromDate(recurrenceEndDate!) : null,
      'nextOccurrence': nextOccurrence != null ? Timestamp.fromDate(nextOccurrence!) : null,
    };
  }
}
