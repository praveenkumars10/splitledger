import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:split_ledger/features/auth/auth_controller.dart';
import '../../core/date_filters.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/language_controller.dart';
import '../../core/preferences/app_preferences.dart';
import '../../core/services/backup_restore_service.dart';
import '../../core/theme/theme_controller.dart';
import '../household/current_household_provider.dart';
import '../transactions/transaction_repository.dart';
import '../household/household_repository.dart';
import '../wallet/wallet_repository.dart';
import '../budget/widgets/category_budget_dialog.dart';
import '../recurring/recurring_page.dart';

class _RecoveryKeyDialog extends ConsumerStatefulWidget {
  final String uid;
  const _RecoveryKeyDialog({required this.uid});

  @override
  ConsumerState<_RecoveryKeyDialog> createState() => _RecoveryKeyDialogState();
}

class _RecoveryKeyDialogState extends ConsumerState<_RecoveryKeyDialog> {
  late final TextEditingController _controller;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final language = ref.read(languageControllerProvider);
    final key = _controller.text.trim();
    if (key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.tr(language, 'enter_recovery_key'))),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authControllerProvider).updateRecoveryKey(widget.uid, key);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.tr(language, 'recovery_key_saved')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageControllerProvider);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.key, color: Colors.blue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppStrings.tr(language, 'recovery_key_settings'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.tr(language, 'recovery_key_desc'),
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              labelText: AppStrings.tr(language, 'recovery_key'),
              hintText: AppStrings.tr(language, 'recovery_key_hint'),
              prefixIcon: const Icon(Icons.shield_outlined),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(AppStrings.tr(language, 'cancel')),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _handleSave,
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(AppStrings.tr(language, 'save')),
        ),
      ],
    );
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  void _showRecoveryKeyDialog(BuildContext context, String uid) {
    showDialog(
      context: context,
      builder: (context) => _RecoveryKeyDialog(uid: uid),
    );
  }

  void _showWalletDialog(BuildContext context, double currentAmount, String uid) {
    showDialog(
      context: context,
      builder: (context) => _SettingsWalletDialog(
        currentAmount: currentAmount,
        uid: uid,
      ),
    );
  }

  void _showRestoreDialog(BuildContext context, String householdId, String currentUid) {
    showDialog(
      context: context,
      builder: (context) => _RestoreDialog(
        householdId: householdId,
        currentUid: currentUid,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = ref.watch(currentHouseholdProvider).asData?.value;
    final currentUser = ref.watch(authStateChangesProvider).asData?.value;
    final walletAmount = ref.watch(currentWalletAmountProvider).asData?.value ?? 0.0;
    final transactions = ref.watch(currentTransactionsProvider).asData?.value ?? [];
    final themeSettings = ref.watch(themeControllerProvider);
    final language = ref.watch(languageControllerProvider);
    final preferences = ref.watch(appPreferencesProvider);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(language, 'settings_tab')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Theme & Appearance
          Row(
            children: [
              Icon(Icons.palette_outlined, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                AppStrings.tr(language, 'appearance_theme'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.tr(language, 'theme_preview_desc'),
            style: TextStyle(fontSize: 13, color: onSurfaceVariant),
          ),
          const SizedBox(height: 12),

          // Live Interactive App Theme Preview Card
          _LiveThemePreviewCard(
            themeSettings: themeSettings,
            language: language,
          ),
          const SizedBox(height: 18),

          // Theme Mode Selector
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                icon: const Icon(Icons.brightness_auto, size: 16),
                label: Text(AppStrings.tr(language, 'theme_mode_system')),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: const Icon(Icons.light_mode, size: 16),
                label: Text(AppStrings.tr(language, 'theme_mode_light')),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: const Icon(Icons.dark_mode, size: 16),
                label: Text(AppStrings.tr(language, 'theme_mode_dark')),
              ),
            ],
            selected: {themeSettings.themeMode},
            onSelectionChanged: (set) {
              ref.read(themeControllerProvider.notifier).setThemeMode(set.first);
            },
          ),
          const SizedBox(height: 16),

          // Accent Color Selector Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppStrings.tr(language, 'theme_accent_color'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onSurfaceVariant),
              ),
              Text(
                themeSettings.accentColor.getLocalizedLabel(language),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: themeSettings.accentColor.color),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Theme Palette Cards Carousel
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: AppThemeColor.values.map((colorItem) {
                final isSelected = themeSettings.accentColor == colorItem;
                return Padding(
                  padding: const EdgeInsets.only(right: 10.0, bottom: 4.0),
                  child: _ThemeColorCard(
                    colorItem: colorItem,
                    isSelected: isSelected,
                    language: language,
                    onTap: () {
                      ref.read(themeControllerProvider.notifier).setAccentColor(colorItem);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 32),

          // Language Setting
          Row(
            children: [
              Icon(Icons.translate, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                AppStrings.tr(language, 'language'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<AppLanguage>(
            segments: AppLanguage.values.map((lang) {
              return ButtonSegment(
                value: lang,
                label: Text('${lang.flag} ${lang.label}'),
              );
            }).toList(),
            selected: {language},
            onSelectionChanged: (set) {
              ref.read(languageControllerProvider.notifier).setLanguage(set.first);
            },
          ),
          const Divider(height: 32),

          // Privacy Mode
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(
              preferences.isPrivacyMode ? Icons.visibility_off : Icons.visibility,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(AppStrings.tr(language, 'privacy_mode'), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(AppStrings.tr(language, 'privacy_mode_sub')),
            value: preferences.isPrivacyMode,
            onChanged: (val) {
              ref.read(appPreferencesProvider.notifier).togglePrivacyMode();
            },
          ),
          const Divider(height: 32),

          // Storage & Data Backup
          Row(
            children: [
              Icon(Icons.storage_outlined, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                AppStrings.tr(language, 'storage_backup_title'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Storage Mode Segmented Switch
          Text(AppStrings.tr(language, 'storage_mode_desc'), style: TextStyle(fontSize: 13, color: onSurfaceVariant)),
          const SizedBox(height: 10),
          SegmentedButton<StorageMode>(
            segments: [
              ButtonSegment(
                value: StorageMode.cloud,
                icon: const Icon(Icons.cloud_sync, size: 16),
                label: Text(AppStrings.tr(language, 'storage_cloud')),
              ),
              ButtonSegment(
                value: StorageMode.local,
                icon: const Icon(Icons.phone_android, size: 16),
                label: Text(AppStrings.tr(language, 'storage_local')),
              ),
            ],
            selected: {preferences.storageMode},
            onSelectionChanged: (set) {
              ref.read(appPreferencesProvider.notifier).setStorageMode(set.first);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${AppStrings.tr(language, 'storage_mode')}: ${set.first.title}')),
              );
            },
          ),
          const SizedBox(height: 16),

          // Backup & Export JSON Tile
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Icon(Icons.cloud_upload_outlined, color: Colors.blue),
            ),
            title: Text(AppStrings.tr(language, 'backup_export'), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(AppStrings.tr(language, 'backup_export_sub')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              if (household != null) {
                final file = await BackupRestoreService.exportBackup(
                  context: context,
                  transactions: transactions,
                  walletAmount: walletAmount,
                  householdName: household.name,
                  members: household.members,
                );
                if (file != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Backup ready and shared!'), backgroundColor: Colors.green),
                  );
                }
              }
            },
          ),

          // Restore JSON Tile
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Icon(Icons.cloud_download_outlined, color: Colors.deepPurple),
            ),
            title: Text(AppStrings.tr(language, 'restore_import'), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(AppStrings.tr(language, 'restore_import_sub')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              if (household != null && currentUser != null) {
                _showRestoreDialog(context, household.id, currentUser.uid);
              }
            },
          ),
          const Divider(height: 32),

          // Account & Security
          Text(
            language == AppLanguage.tamil ? 'பாதுகாப்பு & கணக்கு' : 'Account & Security',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: const Icon(Icons.key_outlined, color: Colors.blue),
            ),
            title: Text(AppStrings.tr(language, 'recovery_key_settings'), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(AppStrings.tr(language, 'recovery_key_settings_sub')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              if (currentUser != null) {
                _showRecoveryKeyDialog(context, currentUser.uid);
              }
            },
          ),
          const Divider(height: 32),

          // Personal Wallet
          Text(
            AppStrings.tr(language, 'wallet'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.account_balance_wallet, color: Theme.of(context).colorScheme.primary),
            title: Text(AppStrings.tr(language, 'wallet_balance')),
            subtitle: Text(
              walletAmount > 0 ? currencyFormat.format(walletAmount) : AppStrings.tr(language, 'wallet_not_set'),
              style: TextStyle(
                fontWeight: walletAmount > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
            onTap: () {
              if (currentUser != null) {
                _showWalletDialog(context, walletAmount, currentUser.uid);
              }
            },
          ),
          const Divider(height: 32),

          // Category Budgets & Spending Limits
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.deepOrange.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.tune_rounded, color: Colors.deepOrange),
            ),
            title: Text(
              AppStrings.tr(language, 'category_budgets'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(AppStrings.tr(language, 'category_budgets_desc')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => CategoryBudgetDialog.show(
              context,
              currentPeriodTransactions: transactions,
            ),
          ),
          const Divider(height: 32),

          // Recurring Expenses & Subscriptions
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.autorenew, color: Colors.teal),
            ),
            title: Text(
              AppStrings.tr(language, 'recurring_expenses'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(AppStrings.tr(language, 'recurring_desc')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RecurringPage()),
            ),
          ),
          const Divider(height: 32),

          // Household Settings
          Text(
            AppStrings.tr(language, 'household_settings'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 16),
          if (household != null) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppStrings.tr(language, 'invite_code'), style: TextStyle(color: onSurfaceVariant)),
              subtitle: Text(
                household.inviteCode,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.copy, color: Theme.of(context).colorScheme.primary),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: household.inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppStrings.tr(language, 'invite_code_copied'))),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.share, color: Theme.of(context).colorScheme.primary),
                    onPressed: () {
                      SharePlus.instance.share(
                        ShareParams(
                          text: 'Hey! Join my SplitLedger household to track our shared expenses.\n\nUse this invite code: ${household.inviteCode}',
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppStrings.tr(language, 'household_name')),
              subtitle: Text(household.name),
              trailing: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (dialogCtx) => _EditHouseholdNameDialog(
                    householdId: household.id,
                    initialName: household.name,
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.calendar_month, color: Colors.teal),
              ),
              title: Text(AppStrings.tr(language, 'salary_cycle'), style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                (household.cycleStartDay) == 1
                    ? 'Day 1 (${AppStrings.tr(language, 'monthly')}: ${getCycleRangeForDate(DateTime.now(), 1).label})'
                    : 'Day ${household.cycleStartDay} (${getCycleRangeForDate(DateTime.now(), household.cycleStartDay).label})',
              ),
              trailing: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (dialogCtx) => _EditCycleStartDayDialog(
                    householdId: household.id,
                    initialCycleStartDay: household.cycleStartDay,
                  ),
                );
              },
            ),
          ] else ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.calendar_month, color: Colors.teal),
              ),
              title: Text(AppStrings.tr(language, 'salary_cycle'), style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                'Day ${preferences.cycleStartDay} (${getCycleRangeForDate(DateTime.now(), preferences.cycleStartDay).label})',
              ),
              trailing: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (dialogCtx) => _EditCycleStartDayDialog(
                    householdId: null,
                    initialCycleStartDay: preferences.cycleStartDay,
                  ),
                );
              },
            ),
          ],
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.help_outline),
            title: Text(AppStrings.tr(language, 'help_support')),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(AppStrings.tr(language, 'help_support')),
                  content: Text(
                    language == AppLanguage.tamil
                        ? 'SplitLedger உங்கள் செலவுகளைக் கண்காணிக்கவும் மாத இறுதியில் சமமாக கணக்கு முடிக்கவும் உதவுகிறது.\n\n'
                          '• நீங்கள் செலவு செய்ததை சேர்க்க "பணம் செலவு" என்பதைப் பயன்படுத்தவும்.\n'
                          '• பணம் பெற்றதை சேர்க்க "பணம் வரவு" என்பதைப் பயன்படுத்தவும்.\n'
                          '• வாலட் மூலம் உங்கள் மொத்த கையிருப்பை அமைத்துக் கொள்ளலாம்.\n'
                          '• அழைப்புக் குறியீட்டைப் பகிர்ந்து உங்கள் துணையை இணைக்கவும்.\n'
                          '• வாட்ஸ்அப் நினைவூட்டல் மற்றும் UPI பே மூலம் நொடியில் பணத்தை மாற்றலாம்.'
                        : 'SplitLedger helps your group track shared expenses and settle up monthly.\n\n'
                          '• Add "You Paid" when you spend money.\n'
                          '• Add "You Received" when you get money back.\n'
                          '• Use Wallet to set your budget / cash balance.\n'
                          '• Your Balance tracks your remaining wallet balance.\n'
                          '• Share your invite code so your partner can join.\n'
                          '• 1-Click WhatsApp Reminder & UPI Pay for effortless settlements.\n'
                          '• Use Data Storage & Backup to export and restore your ledger anytime.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(AppStrings.tr(language, 'done')),
                    ),
                  ],
                ),
              );
            },
          ),
          if (household != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: Text(AppStrings.tr(language, 'clear_all_tx'), style: const TextStyle(color: Colors.red)),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(AppStrings.tr(language, 'clear_all_tx')),
                    content: Text(AppStrings.tr(language, 'clear_all_tx_confirm')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(AppStrings.tr(language, 'cancel')),
                      ),
                      TextButton(
                        onPressed: () async {
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);
                          navigator.pop();
                          try {
                            await ref.read(transactionRepositoryProvider).deleteAllTransactions(household.id);
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(content: Text('Transactions cleared')),
                            );
                          } catch (e) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                        child: Text(AppStrings.tr(language, 'delete'), style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
          if (household != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.exit_to_app, color: Colors.orange),
              title: Text(AppStrings.tr(language, 'leave_household'), style: const TextStyle(color: Colors.orange)),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(AppStrings.tr(language, 'leave_household')),
                    content: Text(AppStrings.tr(language, 'leave_household_confirm')),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(AppStrings.tr(language, 'cancel')),
                      ),
                      TextButton(
                        onPressed: () async {
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);
                          navigator.pop(); // close dialog
                          try {
                            final user = ref.read(authStateChangesProvider).asData?.value;
                            if (user != null) {
                              await ref.read(householdRepositoryProvider).leaveHousehold(household.id, user.uid);
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(content: Text('Left household')),
                              );
                              navigator.popUntil((route) => route.isFirst);
                            }
                          } catch (e) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        },
                        child: Text(AppStrings.tr(language, 'leave_household'), style: const TextStyle(color: Colors.orange)),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'SplitLedger v1.0.0 • Legend Edition 🚀',
              style: TextStyle(fontSize: 12, color: onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SettingsWalletDialog extends ConsumerStatefulWidget {
  final double currentAmount;
  final String uid;

  const _SettingsWalletDialog({
    required this.currentAmount,
    required this.uid,
  });

  @override
  ConsumerState<_SettingsWalletDialog> createState() => _SettingsWalletDialogState();
}

class _SettingsWalletDialogState extends ConsumerState<_SettingsWalletDialog> {
  late final TextEditingController _controller;
  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentAmount > 0 ? widget.currentAmount.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final language = ref.read(languageControllerProvider);
    final raw = _controller.text.trim().toLowerCase();
    double? parsed;
    if (raw.endsWith('k')) {
      final numPart = double.tryParse(raw.replaceAll('k', '').trim());
      if (numPart != null) parsed = numPart * 1000;
    } else {
      parsed = double.tryParse(raw);
    }

    if (parsed != null && parsed >= 0) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      try {
        await ref.read(walletRepositoryProvider).setWalletAmount(widget.uid, parsed);
        messenger.showSnackBar(
          SnackBar(content: Text('${AppStrings.tr(language, 'wallet')}: ${_currencyFormat.format(parsed)}')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error saving wallet: $e')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageControllerProvider);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.account_balance_wallet, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(AppStrings.tr(language, 'wallet_amount')),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.tr(language, 'wallet_desc'),
            style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: AppStrings.tr(language, 'wallet_amount'),
              hintText: 'e.g. 2000',
              prefixText: '₹ ',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [10, 20, 30, 50, 70, 100, 200, 500, 1000, 2000, 5000].map((preset) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: ActionChip(
                    label: Text('₹$preset', style: const TextStyle(fontSize: 12)),
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                    onPressed: () {
                      _controller.text = preset.toString();
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppStrings.tr(language, 'cancel')),
        ),
        FilledButton(
          onPressed: _handleSave,
          child: Text(AppStrings.tr(language, 'save')),
        ),
      ],
    );
  }
}

class _RestoreDialog extends ConsumerStatefulWidget {
  final String householdId;
  final String currentUid;

  const _RestoreDialog({
    required this.householdId,
    required this.currentUid,
  });

  @override
  ConsumerState<_RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends ConsumerState<_RestoreDialog> {
  late final TextEditingController _textController;
  bool _replaceExisting = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleRestore() async {
    final messenger = ScaffoldMessenger.of(context);
    final jsonString = _textController.text.trim();

    if (jsonString.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Please paste backup JSON content')),
      );
      return;
    }

    Navigator.of(context).pop();
    final result = await BackupRestoreService.restoreFromJson(
      ref: ref,
      householdId: widget.householdId,
      currentUid: widget.currentUid,
      rawJson: jsonString,
      replaceExisting: _replaceExisting,
    );

    messenger.showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageControllerProvider);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.restore, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(AppStrings.tr(language, 'restore_import')),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.tr(language, 'restore_import_sub'),
              style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: '{\n  "version": 1,\n  "appName": "SplitLedger",\n  "transactions": [...]\n}',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.paste, size: 16),
              label: Text(AppStrings.tr(language, 'paste_clipboard')),
              onPressed: () async {
                final data = await Clipboard.getData('text/plain');
                if (data?.text != null && mounted) {
                  setState(() {
                    _textController.text = data!.text!;
                  });
                }
              },
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(AppStrings.tr(language, 'replace_existing'), style: const TextStyle(fontSize: 13)),
              subtitle: Text(AppStrings.tr(language, 'replace_existing_sub'), style: const TextStyle(fontSize: 11)),
              value: _replaceExisting,
              onChanged: (val) => setState(() => _replaceExisting = val ?? false),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppStrings.tr(language, 'cancel')),
        ),
        FilledButton(
          onPressed: _handleRestore,
          child: Text(AppStrings.tr(language, 'restore_now')),
        ),
      ],
    );
  }
}

class _EditHouseholdNameDialog extends ConsumerStatefulWidget {
  final String householdId;
  final String initialName;

  const _EditHouseholdNameDialog({
    required this.householdId,
    required this.initialName,
  });

  @override
  ConsumerState<_EditHouseholdNameDialog> createState() => _EditHouseholdNameDialogState();
}

class _EditHouseholdNameDialogState extends ConsumerState<_EditHouseholdNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final newName = _controller.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();

    if (newName.isNotEmpty && newName != widget.initialName) {
      try {
        await ref.read(householdRepositoryProvider).updateHouseholdName(widget.householdId, newName);
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageControllerProvider);

    return AlertDialog(
      title: Text(AppStrings.tr(language, 'edit_household_name')),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(hintText: 'Enter new name'),
        autofocus: true,
        textCapitalization: TextCapitalization.words,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppStrings.tr(language, 'cancel')),
        ),
        TextButton(
          onPressed: _handleSave,
          child: Text(AppStrings.tr(language, 'save')),
        ),
      ],
    );
  }
}

class _EditCycleStartDayDialog extends ConsumerStatefulWidget {
  final String? householdId;
  final int initialCycleStartDay;

  const _EditCycleStartDayDialog({
    required this.householdId,
    required this.initialCycleStartDay,
  });

  @override
  ConsumerState<_EditCycleStartDayDialog> createState() => _EditCycleStartDayDialogState();
}

class _EditCycleStartDayDialogState extends ConsumerState<_EditCycleStartDayDialog> {
  late int _selectedDay;
  late final TextEditingController _dayController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialCycleStartDay.clamp(1, 31);
    _dayController = TextEditingController(text: _selectedDay.toString());
  }

  @override
  void dispose() {
    _dayController.dispose();
    super.dispose();
  }

  void _onDayChanged(int day) {
    final clamped = day.clamp(1, 31);
    setState(() {
      _selectedDay = clamped;
      _dayController.text = clamped.toString();
    });
  }

  Future<void> _handleSave() async {
    final language = ref.read(languageControllerProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);

    try {
      if (widget.householdId != null) {
        await ref
            .read(householdRepositoryProvider)
            .updateHouseholdCycleStartDay(widget.householdId!, _selectedDay);
      }
      await ref.read(appPreferencesProvider.notifier).setCycleStartDay(_selectedDay);

      if (mounted) {
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(
            content: Text(AppStrings.tr(language, 'cycle_saved')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageControllerProvider);
    final now = DateTime.now();
    final currentCycle = getCycleRangeForDate(now, _selectedDay);
    final nextCycle = getCycleRangeWithOffset(now, _selectedDay, 1);
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.calendar_month, color: Colors.teal),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppStrings.tr(language, 'edit_cycle_title'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.tr(language, 'edit_cycle_desc'),
              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.tr(language, 'cycle_start_day'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [1, 5, 7, 10, 15, 25, 30].map((preset) {
                  final isSelected = _selectedDay == preset;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      label: Text(preset == 1 ? '1st (Month)' : '$preset${preset == 7 ? ' ★' : ''}'),
                      selected: isSelected,
                      selectedColor: colorScheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (selected) {
                        if (selected) _onDayChanged(preset);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _selectedDay.toDouble(),
                    min: 1,
                    max: 31,
                    divisions: 30,
                    label: 'Day $_selectedDay',
                    onChanged: (val) => _onDayChanged(val.round()),
                  ),
                ),
                Container(
                  width: 52,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: colorScheme.primary, width: 1.5),
                    borderRadius: BorderRadius.circular(8),
                    color: colorScheme.primary.withValues(alpha: 0.08),
                  ),
                  child: Text(
                    '$_selectedDay',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event_available, size: 16, color: Colors.teal),
                      const SizedBox(width: 6),
                      Text(
                        AppStrings.tr(language, 'active_cycle'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentCycle.label,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.update, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        'Next Cycle: ${nextCycle.label}',
                        style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(AppStrings.tr(language, 'cancel')),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _handleSave,
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(AppStrings.tr(language, 'save')),
        ),
      ],
    );
  }
}

class _LiveThemePreviewCard extends StatelessWidget {
  final ThemeSettings themeSettings;
  final AppLanguage language;

  const _LiveThemePreviewCard({
    required this.themeSettings,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    final previewBrightness = switch (themeSettings.themeMode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => MediaQuery.platformBrightnessOf(context),
    };

    final isDark = previewBrightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: themeSettings.accentColor.color,
      brightness: previewBrightness,
    );

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outlineVariant, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: isDark ? 0.3 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Mini Status Bar (Phone Mockup)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: scheme.primary,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '9:41',
                  style: TextStyle(
                    color: scheme.onPrimary.withValues(alpha: 0.9),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.onPrimary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.wifi, size: 11, color: scheme.onPrimary.withValues(alpha: 0.9)),
                    const SizedBox(width: 4),
                    Icon(Icons.battery_full, size: 12, color: scheme.onPrimary.withValues(alpha: 0.9)),
                  ],
                ),
              ],
            ),
          ),

          // Mini AppBar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: scheme.primary,
            child: Row(
              children: [
                Icon(Icons.book, size: 16, color: scheme.onPrimary),
                const SizedBox(width: 6),
                Text(
                  'SplitLedger',
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.bolt, size: 16, color: Colors.amberAccent),
                const SizedBox(width: 8),
                Icon(Icons.search, size: 15, color: scheme.onPrimary),
              ],
            ),
          ),

          // Mini Body Content
          Container(
            color: scheme.surface,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Active Cycle Capsule & Mode Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_month, size: 10, color: scheme.onPrimaryContainer),
                          const SizedBox(width: 4),
                          Text(
                            '7 Oct – 6 Nov 2026',
                            style: TextStyle(
                              color: scheme.onPrimaryContainer,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.amber.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isDark ? Icons.dark_mode : Icons.light_mode, size: 10, color: Colors.amber),
                          const SizedBox(width: 3),
                          Text(
                            isDark ? 'Dark Mode' : 'Light Mode',
                            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: scheme.onSurface),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Mini Wallet / Balance Card
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.account_balance_wallet, size: 14, color: scheme.primary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.tr(language, 'preview_sample_balance'),
                              style: TextStyle(
                                fontSize: 9.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '₹ 4,850',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 10, color: scheme.onPrimaryContainer),
                            const SizedBox(width: 3),
                            Text(
                              'On Track',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Mini Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bolt, size: 12, color: scheme.onPrimary),
                            const SizedBox(width: 3),
                            Text(
                              AppStrings.tr(language, 'preview_quick_spend'),
                              style: TextStyle(
                                color: scheme.onPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          AppStrings.tr(language, 'you_paid'),
                          style: TextStyle(
                            color: scheme.onSecondaryContainer,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: scheme.primary.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          AppStrings.tr(language, 'settle_up'),
                          style: TextStyle(
                            color: scheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Mini Transaction Tile
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.shopping_cart, size: 11, color: scheme.onPrimaryContainer),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppStrings.tr(language, 'preview_sample_tx'),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: scheme.onSurface,
                              ),
                            ),
                            Text(
                              'Today, 11:30 AM',
                              style: TextStyle(fontSize: 8.5, color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '-₹450',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Mini Bottom Nav Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniNavItem(Icons.home, true, scheme),
                _buildMiniNavItem(Icons.call_split, false, scheme),
                _buildMiniNavItem(Icons.bar_chart, false, scheme),
                _buildMiniNavItem(Icons.settings, false, scheme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniNavItem(IconData icon, bool isActive, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? scheme.primary.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 14,
        color: isActive ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.7),
      ),
    );
  }
}

class _ThemeColorCard extends StatelessWidget {
  final AppThemeColor colorItem;
  final bool isSelected;
  final AppLanguage language;
  final VoidCallback onTap;

  const _ThemeColorCard({
    required this.colorItem,
    required this.isSelected,
    required this.language,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 105,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorItem.color.withValues(alpha: isDark ? 0.25 : 0.12)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colorItem.color : theme.colorScheme.outlineVariant,
            width: isSelected ? 2.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colorItem.color.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Palette Swatch with mini card mockup
            Container(
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorItem.color,
                    colorItem.color.withValues(alpha: 0.75),
                  ],
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Mini preview dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  if (isSelected)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.check, size: 10, color: colorItem.color),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              colorItem.getLocalizedLabel(language),
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? colorItem.color : theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}


