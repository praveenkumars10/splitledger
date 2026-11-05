import 'package:cloud_firestore/cloud_firestore.dart';
import 'transaction_model.dart';
import 'booklet_model.dart';

enum DeletedItemType {
  transaction,
  booklet,
}

/// Immutable audit record stored in `households/{householdId}/deleted_history`.
/// Captures who deleted an item, when it was deleted, and its associated cashbook.
/// Retained for 90 days (3 months) and cannot be deleted by users.
class DeletedAuditItemModel {
  final String id;
  final DeletedItemType type;
  final String deletedByUid;
  final String deletedByName;
  final DateTime deletedAt;

  // Cashbook / Booklet Context
  final String? bookletId;
  final String bookletName;

  // Transaction fields (type == transaction)
  final String? originalTransactionId;
  final double? amount;
  final String? category;
  final String? note;
  final String? paidByUid;
  final String? paidByName;
  final DateTime? transactionDate;
  final String? transactionType; // 'paid' or 'received'
  final String? receiptUrl;
  final Map<String, double>? splitPercentages;
  final Map<String, double>? splitShares;

  // Booklet fields (type == booklet)
  final String? originalBookletId;
  final DateTime? bookletStartDate;
  final DateTime? bookletEndDate;
  final double? bookletOpeningBalance;
  final String? bookletCreatedByName;
  final int? transactionCount;
  final double? totalAmount;

  // Raw original snapshot for data recovery or deep inspection
  final Map<String, dynamic>? rawData;

  const DeletedAuditItemModel({
    required this.id,
    required this.type,
    required this.deletedByUid,
    required this.deletedByName,
    required this.deletedAt,
    this.bookletId,
    required this.bookletName,
    this.originalTransactionId,
    this.amount,
    this.category,
    this.note,
    this.paidByUid,
    this.paidByName,
    this.transactionDate,
    this.transactionType,
    this.receiptUrl,
    this.splitPercentages,
    this.splitShares,
    this.originalBookletId,
    this.bookletStartDate,
    this.bookletEndDate,
    this.bookletOpeningBalance,
    this.bookletCreatedByName,
    this.transactionCount,
    this.totalAmount,
    this.rawData,
  });

  /// Factory helper to build an audit record from a deleted transaction
  factory DeletedAuditItemModel.fromTransaction({
    required String id,
    required TransactionModel transaction,
    required String deletedByUid,
    required String deletedByName,
    String? bookletName,
    DateTime? deletedAt,
  }) {
    return DeletedAuditItemModel(
      id: id,
      type: DeletedItemType.transaction,
      deletedByUid: deletedByUid,
      deletedByName: deletedByName.trim().isEmpty ? 'Member' : deletedByName.trim(),
      deletedAt: deletedAt ?? DateTime.now(),
      bookletId: transaction.bookletId,
      bookletName: (bookletName != null && bookletName.trim().isNotEmpty)
          ? bookletName.trim()
          : 'Cashbook 1',
      originalTransactionId: transaction.id,
      amount: transaction.amount,
      category: transaction.category,
      note: transaction.note,
      paidByUid: transaction.paidByUid,
      paidByName: transaction.paidByName,
      transactionDate: transaction.date,
      transactionType: transaction.type.name,
      receiptUrl: transaction.receiptUrl,
      splitPercentages: transaction.splitPercentages,
      splitShares: transaction.splitShares,
      rawData: transaction.toMap(),
    );
  }

  /// Factory helper to build an audit record from a deleted booklet
  factory DeletedAuditItemModel.fromBooklet({
    required String id,
    required BookletModel booklet,
    required String deletedByUid,
    required String deletedByName,
    int? transactionCount,
    double? totalAmount,
    DateTime? deletedAt,
  }) {
    return DeletedAuditItemModel(
      id: id,
      type: DeletedItemType.booklet,
      deletedByUid: deletedByUid,
      deletedByName: deletedByName.trim().isEmpty ? 'Member' : deletedByName.trim(),
      deletedAt: deletedAt ?? DateTime.now(),
      bookletId: booklet.id,
      bookletName: booklet.name,
      originalBookletId: booklet.id,
      bookletStartDate: booklet.startDate,
      bookletEndDate: booklet.endDate,
      bookletOpeningBalance: booklet.openingBalance,
      bookletCreatedByName: booklet.createdByName,
      transactionCount: transactionCount,
      totalAmount: totalAmount,
      rawData: booklet.toMap(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'deletedByUid': deletedByUid,
      'deletedByName': deletedByName,
      'deletedAt': Timestamp.fromDate(deletedAt),
      'bookletId': bookletId,
      'bookletName': bookletName,
      'originalTransactionId': originalTransactionId,
      'amount': amount,
      'category': category,
      'note': note,
      'paidByUid': paidByUid,
      'paidByName': paidByName,
      'transactionDate': transactionDate != null ? Timestamp.fromDate(transactionDate!) : null,
      'transactionType': transactionType,
      'receiptUrl': receiptUrl,
      'splitPercentages': splitPercentages,
      'splitShares': splitShares,
      'originalBookletId': originalBookletId,
      'bookletStartDate': bookletStartDate != null ? Timestamp.fromDate(bookletStartDate!) : null,
      'bookletEndDate': bookletEndDate != null ? Timestamp.fromDate(bookletEndDate!) : null,
      'bookletOpeningBalance': bookletOpeningBalance,
      'bookletCreatedByName': bookletCreatedByName,
      'transactionCount': transactionCount,
      'totalAmount': totalAmount,
      'rawData': rawData,
    };
  }

  factory DeletedAuditItemModel.fromMap(Map<String, dynamic> map, String id) {
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

    final typeStr = map['type'] as String? ?? 'transaction';
    final type = typeStr == 'booklet' ? DeletedItemType.booklet : DeletedItemType.transaction;

    Map<String, double>? parseDoublesMap(dynamic val) {
      if (val is Map) {
        return val.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()));
      }
      return null;
    }

    return DeletedAuditItemModel(
      id: id,
      type: type,
      deletedByUid: map['deletedByUid'] ?? '',
      deletedByName: map['deletedByName'] ?? 'Unknown Member',
      deletedAt: parseDate(map['deletedAt']),
      bookletId: map['bookletId'],
      bookletName: map['bookletName'] ?? 'Cashbook 1',
      originalTransactionId: map['originalTransactionId'],
      amount: (map['amount'] as num?)?.toDouble(),
      category: map['category'],
      note: map['note'],
      paidByUid: map['paidByUid'],
      paidByName: map['paidByName'],
      transactionDate: parseNullableDate(map['transactionDate']),
      transactionType: map['transactionType'],
      receiptUrl: map['receiptUrl'],
      splitPercentages: parseDoublesMap(map['splitPercentages']),
      splitShares: parseDoublesMap(map['splitShares']),
      originalBookletId: map['originalBookletId'],
      bookletStartDate: parseNullableDate(map['bookletStartDate']),
      bookletEndDate: parseNullableDate(map['bookletEndDate']),
      bookletOpeningBalance: (map['bookletOpeningBalance'] as num?)?.toDouble(),
      bookletCreatedByName: map['bookletCreatedByName'],
      transactionCount: (map['transactionCount'] as num?)?.toInt(),
      totalAmount: (map['totalAmount'] as num?)?.toDouble(),
      rawData: map['rawData'] is Map ? Map<String, dynamic>.from(map['rawData']) : null,
    );
  }
}

