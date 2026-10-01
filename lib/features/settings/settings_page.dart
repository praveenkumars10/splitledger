import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:split_ledger/features/auth/auth_controller.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/language_controller.dart';
import '../../core/preferences/app_preferences.dart';
import '../../core/services/backup_restore_service.dart';
import '../../core/theme/theme_controller.dart';
import '../household/current_household_provider.dart';
import '../transactions/transaction_repository.dart';
import '../household/household_repository.dart';
import '../wallet/wallet_repository.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  void _showWalletDialog(BuildContext context, WidgetRef ref, double currentAmount, String uid) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final controller = TextEditingController(
      text: currentAmount > 0 ? currentAmount.toStringAsFixed(0) : '',
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Wallet Amount'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the total amount in your wallet/bank (e.g. 2000 or 2k):',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Wallet Amount',
                hintText: 'e.g. 2000',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // Quick preset chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [10, 20, 30, 50, 70, 100, 200, 500, 1000, 2000, 5000].map((preset) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ActionChip(
                      label: Text('₹$preset', style: const TextStyle(fontSize: 12)),
                      backgroundColor: Colors.deepPurple.shade50,
                      side: BorderSide(color: Colors.deepPurple.shade200),
                      onPressed: () {
                        controller.text = preset.toString();
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
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final raw = controller.text.trim().toLowerCase();
              double? parsed;
              if (raw.endsWith('k')) {
                final numPart = double.tryParse(raw.replaceAll('k', '').trim());
                if (numPart != null) parsed = numPart * 1000;
              } else {
                parsed = double.tryParse(raw);
              }
              if (parsed != null && parsed >= 0) {
                Navigator.pop(context);
                try {
                  await ref.read(walletRepositoryProvider).setWalletAmount(uid, parsed);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Wallet set to ${currencyFormat.format(parsed)}')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error saving wallet: $e')),
                    );
                  }
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid amount')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog(BuildContext context, WidgetRef ref, String householdId, String currentUid) {
    final textController = TextEditingController();
    bool replaceExisting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.restore, color: Colors.deepPurple),
              SizedBox(width: 8),
              Text('Restore Backup'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Paste your SplitLedger JSON backup content below:',
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
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
                  label: const Text('Paste from Clipboard'),
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) {
                      setState(() {
                        textController.text = data!.text!;
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Replace existing transactions', style: TextStyle(fontSize: 13)),
                  subtitle: const Text('If checked, current transactions will be cleared first', style: TextStyle(fontSize: 11)),
                  value: replaceExisting,
                  onChanged: (val) => setState(() => replaceExisting = val ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final jsonString = textController.text.trim();
                if (jsonString.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please paste backup JSON content')),
                  );
                  return;
                }

                Navigator.pop(context);
                final messenger = ScaffoldMessenger.of(context);
                final result = await BackupRestoreService.restoreFromJson(
                  ref: ref,
                  householdId: householdId,
                  currentUid: currentUid,
                  rawJson: jsonString,
                  replaceExisting: replaceExisting,
                );

                messenger.showSnackBar(
                  SnackBar(
                    content: Text(result.message),
                    backgroundColor: result.success ? Colors.green : Colors.red,
                  ),
                );
              },
              child: const Text('Restore Now'),
            ),
          ],
        ),
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
          const SizedBox(height: 12),
          // Theme Mode Selector
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto, size: 16),
                label: Text('System'),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode, size: 16),
                label: Text('Light'),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode, size: 16),
                label: Text('Dark'),
              ),
            ],
            selected: {themeSettings.themeMode},
            onSelectionChanged: (set) {
              ref.read(themeControllerProvider.notifier).setThemeMode(set.first);
            },
          ),
          const SizedBox(height: 16),
          // Accent Color Selector
          const Text('Theme Accent Color', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: AppThemeColor.values.map((colorItem) {
                final isSelected = themeSettings.accentColor == colorItem;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    avatar: CircleAvatar(
                      backgroundColor: colorItem.color,
                      radius: 8,
                    ),
                    label: Text(colorItem.label),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        ref.read(themeControllerProvider.notifier).setAccentColor(colorItem);
                      }
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
          Text(AppStrings.tr(language, 'storage_mode_desc'), style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
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
                SnackBar(content: Text('Storage set to: ${set.first.title}')),
              );
            },
          ),
          const SizedBox(height: 16),

          // Backup & Export JSON Tile
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
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
              decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.cloud_download_outlined, color: Colors.deepPurple),
            ),
            title: Text(AppStrings.tr(language, 'restore_import'), style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(AppStrings.tr(language, 'restore_import_sub')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              if (household != null && currentUser != null) {
                _showRestoreDialog(context, ref, household.id, currentUser.uid);
              }
            },
          ),
          const Divider(height: 32),

          // Personal Wallet
          const Text(
            'Personal Wallet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.account_balance_wallet, color: Colors.deepPurple),
            title: const Text('Your Wallet Balance'),
            subtitle: Text(
              walletAmount > 0 ? currencyFormat.format(walletAmount) : 'Not configured (Tap to set)',
              style: TextStyle(
                fontWeight: walletAmount > 0 ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            trailing: const Icon(Icons.edit, color: Colors.deepPurple),
            onTap: () {
              if (currentUser != null) {
                _showWalletDialog(context, ref, walletAmount, currentUser.uid);
              }
            },
          ),
          const Divider(height: 32),

          // Household Settings
          const Text(
            'Household Settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          const SizedBox(height: 16),
          if (household != null) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Your Invite Code', style: TextStyle(color: Colors.grey)),
              subtitle: Text(
                household.inviteCode,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.blue),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: household.inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invite code copied to clipboard!')),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.blue),
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
              title: const Text('Household Name'),
              subtitle: Text(household.name),
              trailing: const Icon(Icons.edit, color: Colors.blue),
              onTap: () {
                final controller = TextEditingController(text: household.name);
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Edit Household Name'),
                    content: TextField(
                      controller: controller,
                      decoration: const InputDecoration(hintText: 'Enter new name'),
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final newName = controller.text.trim();
                          if (newName.isNotEmpty && newName != household.name) {
                            Navigator.pop(context);
                            try {
                              await ref.read(householdRepositoryProvider).updateHouseholdName(household.id, newName);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ] else ...[
            const Text('No active household.'),
          ],
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Support'),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Help & Support'),
                  content: const Text(
                    'SplitLedger helps your group track shared expenses and settle up monthly.\n\n'
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
                      child: const Text('Got it'),
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
              title: const Text('Clear All Transactions', style: TextStyle(color: Colors.red)),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear All Transactions?'),
                    content: const Text('Are you sure you want to delete ALL transactions in this household? This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
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
                        child: const Text('Delete All', style: TextStyle(color: Colors.red)),
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
              title: const Text('Leave Household', style: TextStyle(color: Colors.orange)),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Leave Household?'),
                    content: const Text('Are you sure you want to leave this household? You will no longer have access to its transactions.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
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
                        child: const Text('Leave', style: TextStyle(color: Colors.orange)),
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
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

