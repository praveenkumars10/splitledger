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

  void _showRecoveryKeyDialog(BuildContext context, WidgetRef ref, String uid) {
    final language = ref.read(languageControllerProvider);
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) => AlertDialog(
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
                  style: TextStyle(fontSize: 13, color: Theme.of(dialogCtx).colorScheme.onSurface),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
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
                onPressed: isLoading ? null : () => Navigator.of(dialogCtx).pop(),
                child: Text(AppStrings.tr(language, 'cancel')),
              ),
              FilledButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        final key = controller.text.trim();
                        if (key.isEmpty) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(AppStrings.tr(language, 'enter_recovery_key'))),
                          );
                          return;
                        }
                        setDialogState(() => isLoading = true);
                        try {
                          await ref.read(authControllerProvider).updateRecoveryKey(uid, key);
                          if (dialogCtx.mounted) {
                            Navigator.of(dialogCtx).pop();
                          }
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(AppStrings.tr(language, 'recovery_key_saved')),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          if (dialogCtx.mounted) {
                            setDialogState(() => isLoading = false);
                          }
                          messenger.showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      },
                child: isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(AppStrings.tr(language, 'save')),
              ),
            ],
          ),
        );
      },
    ).then((_) => controller.dispose());
  }

  void _showWalletDialog(BuildContext context, WidgetRef ref, double currentAmount, String uid) {
    final language = ref.read(languageControllerProvider);
    final messenger = ScaffoldMessenger.of(context);
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
    final controller = TextEditingController(
      text: currentAmount > 0 ? currentAmount.toStringAsFixed(0) : '',
    );
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Theme.of(dialogCtx).colorScheme.primary),
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
              style: TextStyle(fontSize: 13, color: Theme.of(dialogCtx).colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
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
            // Quick preset chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [10, 20, 30, 50, 70, 100, 200, 500, 1000, 2000, 5000].map((preset) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ActionChip(
                      label: Text('₹$preset', style: const TextStyle(fontSize: 12)),
                      backgroundColor: Theme.of(dialogCtx).colorScheme.primary.withValues(alpha: 0.1),
                      side: BorderSide(color: Theme.of(dialogCtx).colorScheme.primary.withValues(alpha: 0.3)),
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
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(AppStrings.tr(language, 'cancel')),
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
                Navigator.of(dialogCtx).pop();
                try {
                  await ref.read(walletRepositoryProvider).setWalletAmount(uid, parsed);
                  messenger.showSnackBar(
                    SnackBar(content: Text('${AppStrings.tr(language, 'wallet')}: ${currencyFormat.format(parsed)}')),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Error saving wallet: $e')),
                  );
                }
              } else {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Please enter a valid amount')),
                );
              }
            },
            child: Text(AppStrings.tr(language, 'save')),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _showRestoreDialog(BuildContext context, WidgetRef ref, String householdId, String currentUid) {
    final language = ref.read(languageControllerProvider);
    final messenger = ScaffoldMessenger.of(context);
    final textController = TextEditingController();
    bool replaceExisting = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.restore, color: Theme.of(dialogCtx).colorScheme.primary),
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
                  style: TextStyle(fontSize: 13, color: Theme.of(dialogCtx).colorScheme.onSurface),
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
                  label: Text(AppStrings.tr(language, 'paste_clipboard')),
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) {
                      setDialogState(() {
                        textController.text = data!.text!;
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(AppStrings.tr(language, 'replace_existing'), style: const TextStyle(fontSize: 13)),
                  subtitle: Text(AppStrings.tr(language, 'replace_existing_sub'), style: const TextStyle(fontSize: 11)),
                  value: replaceExisting,
                  onChanged: (val) => setDialogState(() => replaceExisting = val ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(AppStrings.tr(language, 'cancel')),
            ),
            FilledButton(
              onPressed: () async {
                final jsonString = textController.text.trim();
                if (jsonString.isEmpty) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Please paste backup JSON content')),
                  );
                  return;
                }

                Navigator.of(dialogCtx).pop();
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
              child: Text(AppStrings.tr(language, 'restore_now')),
            ),
          ],
        ),
      ),
    ).then((_) => textController.dispose());
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
          const SizedBox(height: 12),
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
          // Accent Color Selector
          Text(AppStrings.tr(language, 'theme_accent_color'), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: onSurfaceVariant)),
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
                    label: Text(
                      colorItem.getLocalizedLabel(language),
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
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
                _showRestoreDialog(context, ref, household.id, currentUser.uid);
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
                _showRecoveryKeyDialog(context, ref, currentUser.uid);
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
                _showWalletDialog(context, ref, walletAmount, currentUser.uid);
              }
            },
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
                final messenger = ScaffoldMessenger.of(context);
                final controller = TextEditingController(text: household.name);
                showDialog(
                  context: context,
                  builder: (dialogCtx) => AlertDialog(
                    title: Text(AppStrings.tr(language, 'edit_household_name')),
                    content: TextField(
                      controller: controller,
                      decoration: const InputDecoration(hintText: 'Enter new name'),
                      autofocus: true,
                      textCapitalization: TextCapitalization.words,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        child: Text(AppStrings.tr(language, 'cancel')),
                      ),
                      TextButton(
                        onPressed: () async {
                          final newName = controller.text.trim();
                          if (newName.isNotEmpty && newName != household.name) {
                            Navigator.of(dialogCtx).pop();
                            try {
                              await ref.read(householdRepositoryProvider).updateHouseholdName(household.id, newName);
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          } else {
                            Navigator.of(dialogCtx).pop();
                          }
                        },
                        child: Text(AppStrings.tr(language, 'save')),
                      ),
                    ],
                  ),
                ).then((_) => controller.dispose());
              },
            ),
          ] else ...[
            const Text('No active household.'),
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
