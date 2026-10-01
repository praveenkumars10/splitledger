import 'package:intl/intl.dart';

final NumberFormat _currencyFormat =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹');

/// Formats an amount as Indian Rupees, e.g. ₹1,234.50
String formatCurrency(double value) => _currencyFormat.format(value);

/// Shortens an email-derived name to just the part before the '@'.
String shortName(String name) =>
    name.contains('@') ? name.split('@').first : name;

/// Returns an appropriate emoji for a given category or note string.
String getCategoryEmoji(String text) {
  final lower = text.toLowerCase().trim();
  if (lower.contains('food') || lower.contains('restaurant') || lower.contains('snack') || lower.contains('tea') || lower.contains('lunch') || lower.contains('dinner') || lower.contains('coffee') || lower.contains('breakfast')) return '🍔';
  if (lower.contains('grocer') || lower.contains('vegetable') || lower.contains('milk') || lower.contains('provision') || lower.contains('fruit')) return '🛒';
  if (lower.contains('travel') || lower.contains('fuel') || lower.contains('petrol') || lower.contains('diesel') || lower.contains('cab') || lower.contains('auto') || lower.contains('bus') || lower.contains('uber') || lower.contains('ola') || lower.contains('flight') || lower.contains('train')) return '🚗';
  if (lower.contains('bill') || lower.contains('electric') || lower.contains('wifi') || lower.contains('recharge') || lower.contains('eb') || lower.contains('water') || lower.contains('gas')) return '💡';
  if (lower.contains('rent') || lower.contains('room') || lower.contains('house') || lower.contains('maintenance')) return '🏠';
  if (lower.contains('shop') || lower.contains('cloth') || lower.contains('dress') || lower.contains('amazon') || lower.contains('flipkart')) return '🛍️';
  if (lower.contains('med') || lower.contains('doctor') || lower.contains('pharmacy') || lower.contains('hospital') || lower.contains('tablet') || lower.contains('clinic')) return '💊';
  if (lower.contains('movie') || lower.contains('game') || lower.contains('ott') || lower.contains('netflix') || lower.contains('entertainment')) return '🎬';
  if (lower.contains('salary') || lower.contains('income') || lower.contains('bonus') || lower.contains('settle') || lower.contains('cash')) return '💵';
  return '📝';
}

/// Human friendly day header: Today / Yesterday / "Mon, 05 Jan 2026".
String formatDayHeader(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  if (day == today) return 'Today';
  if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return DateFormat('EEE, dd MMM yyyy').format(date);
}
