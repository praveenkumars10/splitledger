import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DailyBudgetCard extends StatelessWidget {
  final double walletAmount;
  final double userTotalSpend;
  final VoidCallback? onSetWalletTap;

  const DailyBudgetCard({
    super.key,
    required this.walletAmount,
    required this.userTotalSpend,
    this.onSetWalletTap,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final daysLeft = (lastDay - now.day + 1).clamp(1, 31);

    final remaining = (walletAmount > 0) ? (walletAmount - userTotalSpend) : 0.0;
    final dailyBudget = (walletAmount > 0 && remaining > 0) ? (remaining / daysLeft) : 0.0;

    final isConfigured = walletAmount > 0;

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (!isConfigured) {
      statusColor = Colors.grey.shade600;
      statusText = 'Set Wallet to calculate daily budget';
      statusIcon = Icons.info_outline;
    } else if (remaining <= 0) {
      statusColor = Colors.red.shade600;
      statusText = 'Over budget for this month';
      statusIcon = Icons.warning_amber_rounded;
    } else if (dailyBudget < 100) {
      statusColor = Colors.orange.shade700;
      statusText = 'Tight Budget: Spend carefully';
      statusIcon = Icons.speed_rounded;
    } else {
      statusColor = const Color(0xFF0F766E);
      statusText = 'On Track: Healthy budget';
      statusIcon = Icons.check_circle_outline;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              statusColor.withValues(alpha: 0.08),
              Theme.of(context).cardColor,
            ],
          ),
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.today, color: statusColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daily Spend Target',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$daysLeft days left in ${DateFormat('MMMM').format(now)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                if (onSetWalletTap != null)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: onSetWalletTap,
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text('Wallet', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const Divider(height: 20),
            if (!isConfigured)
              InkWell(
                onTap: onSetWalletTap,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Row(
                    children: [
                      Icon(statusIcon, color: statusColor, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          statusText,
                          style: TextStyle(fontSize: 13, color: statusColor, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                    ],
                  ),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currencyFormat.format(dailyBudget),
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                      const Text(
                        'per day safe spend',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          statusText,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
