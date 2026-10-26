import 'package:intl/intl.dart';
import '../models/transaction_model.dart';

/// Represents a billing or salary cycle date range for expense tracking.
class DateCycleRange {
  final DateTime start;
  final DateTime end;
  final String label;
  final int cycleStartDay;

  const DateCycleRange({
    required this.start,
    required this.end,
    required this.label,
    required this.cycleStartDay,
  });

  /// Returns true if [date] falls within this cycle range (inclusive).
  bool contains(DateTime date) {
    return isInDateRange(date, start, end);
  }

  /// Calculates days remaining in this cycle from [fromDate] (defaults to today).
  int daysRemaining([DateTime? fromDate]) {
    final now = fromDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final e = DateTime(end.year, end.month, end.day);
    if (today.isAfter(e)) return 0;
    return e.difference(today).inDays + 1;
  }
}

/// Returns the number of days in the given month and year.
int getDaysInMonth(int year, int month) {
  return DateTime(year, month + 1, 0).day;
}

/// Clamps [day] to the valid days of [month]/[year].
DateTime clampDate(int year, int month, int day, {bool endOfDay = false}) {
  final maxDays = getDaysInMonth(year, month);
  final d = day.clamp(1, maxDays);
  if (endOfDay) {
    return DateTime(year, month, d, 23, 59, 59, 999);
  }
  return DateTime(year, month, d);
}

/// Computes the [DateCycleRange] containing [referenceDate] for the specified [cycleStartDay] (1..31).
DateCycleRange getCycleRangeForDate(DateTime referenceDate, int cycleStartDay) {
  final day = cycleStartDay.clamp(1, 31);
  if (day <= 1) {
    final start = DateTime(referenceDate.year, referenceDate.month, 1);
    final end = clampDate(referenceDate.year, referenceDate.month, 31, endOfDay: true);
    final label = DateFormat('MMM yyyy').format(start);
    return DateCycleRange(start: start, end: end, label: label, cycleStartDay: 1);
  }

  int startYear = referenceDate.year;
  int startMonth = referenceDate.month;
  if (referenceDate.day < day) {
    if (startMonth == 1) {
      startYear--;
      startMonth = 12;
    } else {
      startMonth--;
    }
  }

  final start = clampDate(startYear, startMonth, day);
  final endYear = startMonth == 12 ? startYear + 1 : startYear;
  final endMonth = startMonth == 12 ? 1 : startMonth + 1;
  final end = clampDate(endYear, endMonth, day - 1, endOfDay: true);

  final startLabel = DateFormat('d MMM').format(start);
  final endLabel = DateFormat('d MMM yyyy').format(end);
  final label = '$startLabel – $endLabel';

  return DateCycleRange(
    start: start,
    end: end,
    label: label,
    cycleStartDay: day,
  );
}

/// Navigates cycles by [monthOffset] (e.g. -1 for previous cycle, +1 for next cycle).
DateCycleRange getCycleRangeWithOffset(DateTime baseDate, int cycleStartDay, int monthOffset) {
  final current = getCycleRangeForDate(baseDate, cycleStartDay);
  if (monthOffset == 0) return current;

  int m = current.start.month + monthOffset;
  int y = current.start.year;
  while (m > 12) {
    m -= 12;
    y++;
  }
  while (m < 1) {
    m += 12;
    y--;
  }

  final target = clampDate(y, m, cycleStartDay.clamp(1, 31));
  return getCycleRangeForDate(target, cycleStartDay);
}

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
/// [timeFilter] must be one of: 'All', 'Daily', 'Weekly', 'Monthly', 'Cycle', 'Yearly'.
/// [userFilter] must be 'all', 'me', 'group', or a specific user's UID.
/// [currentUserId] is required when [userFilter] is not 'All Users'.
/// [cycleStartDay] defaults to 1 (calendar month) or customized day (e.g. 7).
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
  int cycleStartDay = 1,
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
      case 'Cycle':
        if (cycleStartDay > 1) {
          final target = selectedMonth ?? now;
          final cycle = getCycleRangeForDate(target, cycleStartDay);
          if (!cycle.contains(tx.date)) return false;
        } else {
          if (selectedMonth == null) {
            if (!isInMonth(tx.date, now)) return false;
          } else {
            if (!isInMonth(tx.date, selectedMonth)) return false;
          }
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
