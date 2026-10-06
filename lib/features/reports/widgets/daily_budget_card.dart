import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/language_controller.dart';

class DailyBudgetCard extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageControllerProvider);
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
      statusColor = Theme.of(context).colorScheme.primary;
      statusText = AppStrings.tr(language, 'set_wallet_target');
      statusIcon = Icons.info_outline;
    } else if (remaining <= 0) {
      statusColor = Colors.red.shade600;
      statusText = AppStrings.tr(language, 'over_budget');
      statusIcon = Icons.warning_amber_rounded;
    } else if (dailyBudget < 100) {
      statusColor = Colors.orange.shade700;
      statusText = AppStrings.tr(language, 'tight_budget');
      statusIcon = Icons.speed_rounded;
    } else {
      statusColor = const Color(0xFF0F766E);
      statusText = AppStrings.tr(language, 'on_track');
      statusIcon = Icons.check_circle_outline;
    }

    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

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
                      Text(
                        AppStrings.tr(language, 'daily_spend_target'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '$daysLeft ${AppStrings.tr(language, 'days_left_in')} ${DateFormat('MMMM').format(now)}',
                        style: TextStyle(fontSize: 12, color: onSurfaceVariant),
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
                    label: Text(AppStrings.tr(language, 'wallet'), style: const TextStyle(fontSize: 12)),
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
                          style: TextStyle(fontSize: 13, color: statusColor, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(Icons.chevron_right, size: 18, color: onSurfaceVariant),
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
                      Text(
                        AppStrings.tr(language, 'safe_spend_per_day'),
                        style: TextStyle(fontSize: 12, color: onSurfaceVariant),
                      ),
                    ],
                  ),
                  Flexible(
                    child: Container(
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
                          Flexible(
                            child: Text(
                              statusText,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
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
