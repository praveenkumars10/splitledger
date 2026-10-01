import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Daily Budget & Expense Insights Calculations', () {
    test('Calculates safe daily budget correctly with remaining balance', () {
      const double walletAmount = 3000.0;
      const double spent = 1000.0;
      const int daysLeft = 10;

      final remaining = walletAmount - spent;
      expect(remaining, 2000.0);

      final safeDaily = remaining / daysLeft;
      expect(safeDaily, 200.0);
    });

    test('Zero or negative remaining balance returns 0 safe daily budget', () {
      const double walletAmount = 2000.0;
      const double spent = 2500.0;
      const int daysLeft = 15;

      final remaining = walletAmount - spent;
      final safeDaily = (walletAmount > 0 && remaining > 0) ? (remaining / daysLeft) : 0.0;
      expect(safeDaily, 0.0);
    });

    test('Category percentage breakdown calculations sum correctly', () {
      final categoryExpenses = {'food': 500.0, 'fuel': 300.0, 'tea': 200.0};
      final total = categoryExpenses.values.fold(0.0, (s, v) => s + v);

      expect(total, 1000.0);
      expect((categoryExpenses['food']! / total) * 100, 50.0);
      expect((categoryExpenses['fuel']! / total) * 100, 30.0);
      expect((categoryExpenses['tea']! / total) * 100, 20.0);
    });
  });
}
