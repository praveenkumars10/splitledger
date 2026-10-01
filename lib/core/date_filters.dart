import '../models/transaction_model.dart';

/// Returns true if [date] falls inside [month] (year + month only).
bool isInMonth(DateTime date, DateTime month) {
  return date.year == month.year && date.month == month.month;
}

/// Returns true if [date] is between [start] and [end] inclusive.
bool isInDateRange(DateTime date, DateTime start, DateTime end) {
  final d = DateTime(date.year, date.month, date.day);
  final s = DateTime(start.year, start.month, start.day);
  final e = DateTime(end.year, end.month, end.day);
  return !d.isBefore(s) && !d.isAfter(e);
}

/// Returns true if [date] is today.
bool isToday(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(date.year, date.month, date.day);
  return d == today;
}

/// Returns true if [date] is within the last 7 days including today.
bool isThisWeek(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(date.year, date.month, date.day);
  final diff = today.difference(d).inDays;
  return diff >= 0 && diff < 7;
}

/// Returns true if [date] is in the current calendar year.
bool isThisYear(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year;
}

/// Filters a list of transactions by the named time filter and optional user filter.
///
/// [timeFilter] must be one of: 'All', 'Daily', 'Weekly', 'Monthly', 'Yearly'.
/// [userFilter] must be 'all', 'me', 'group', or a specific user's UID.
/// [currentUserId] is required when [userFilter] is not 'All Users'.
List<TransactionModel> filterTransactions(
  List<TransactionModel> transactions, {
  required String timeFilter,
  required String userFilter,
  String? currentUserId,
  DateTime? selectedMonth,
  DateTime? rangeStart,
  DateTime? rangeEnd,
  String? keyword,
  double? minAmount,
  double? maxAmount,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  return transactions.where((tx) {
    // User filter
    if (userFilter == 'me' && tx.paidByUid != currentUserId) {
      return false;
    }
    if (userFilter == 'group' && tx.paidByUid == currentUserId) {
      return false;
    }
    if (userFilter != 'all' && userFilter != 'me' && userFilter != 'group') {
      if (tx.paidByUid != userFilter) return false;
    }

    final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);

    // Time filter
    switch (timeFilter) {
      case 'Daily':
        if (txDate != today) return false;
      case 'Weekly':
        if (!isThisWeek(tx.date)) return false;
      case 'Monthly':
        if (selectedMonth == null) {
          if (!isInMonth(tx.date, now)) return false;
        } else {
          if (!isInMonth(tx.date, selectedMonth)) return false;
        }
      case 'Yearly':
        if (!isThisYear(tx.date)) return false;
      case 'All':
      default:
        break;
    }

    // Date range filter
    if (rangeStart != null && rangeEnd != null) {
      if (!isInDateRange(tx.date, rangeStart, rangeEnd)) return false;
    }

    // Keyword filter
    if (keyword != null && keyword.trim().isNotEmpty) {
      final query = keyword.toLowerCase();
      final note = tx.note?.toLowerCase() ?? '';
      final category = tx.category.toLowerCase();
      final paidBy = tx.paidByName.toLowerCase();
      if (!note.contains(query) && !category.contains(query) && !paidBy.contains(query)) {
        return false;
      }
    }

    // Amount filter
    if (minAmount != null && tx.amount < minAmount) return false;
    if (maxAmount != null && tx.amount > maxAmount) return false;

    return true;
  }).toList();
}
