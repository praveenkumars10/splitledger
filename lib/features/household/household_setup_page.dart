import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/language_controller.dart';
import '../auth/auth_controller.dart';
import 'household_repository.dart';

class HouseholdSetupPage extends ConsumerStatefulWidget {
  const HouseholdSetupPage({super.key});

  @override
  ConsumerState<HouseholdSetupPage> createState() => _HouseholdSetupPageState();
}

class _HouseholdSetupPageState extends ConsumerState<HouseholdSetupPage> {
  final _inviteCodeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  String _userName() {
    final user = ref.read(authStateChangesProvider).asData?.value;
    final displayName = user?.displayName;
    if (displayName != null && displayName.trim().isNotEmpty) return displayName.trim();
    return user?.email ?? 'Unknown';
  }

  void _createHousehold() async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(authStateChangesProvider).asData?.value;
      if (user == null) throw Exception('Not logged in');

      final household = await ref
          .read(householdRepositoryProvider)
          .createHousehold(user.uid, _userName());

      if (mounted) {
        // AuthGate navigates to MainPage automatically once the household
        // stream emits; show the invite code so the partner can join.
        await _showInviteCodeDialog(household.inviteCode);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showInviteCodeDialog(String inviteCode) {
    final language = ref.read(languageControllerProvider);
    return showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppStrings.tr(language, 'setup_household')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppStrings.tr(language, 'invite_code')),
            const SizedBox(height: 16),
            SelectableText(
              inviteCode,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy),
            label: Text(AppStrings.tr(language, 'copy')),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: inviteCode));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(AppStrings.tr(language, 'invite_code_copied'))),
                );
              }
            },
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(AppStrings.tr(language, 'done')),
          ),
        ],
      ),
    );
  }

  void _joinHousehold() async {
    final language = ref.read(languageControllerProvider);
    if (_inviteCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.tr(language, 'enter_invite_code'))));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = ref.read(authStateChangesProvider).asData?.value;
      if (user == null) throw Exception('Not logged in');

      await ref.read(householdRepositoryProvider).joinHousehold(
            _inviteCodeController.text.trim().toUpperCase(),
            user.uid,
            _userName(),
          );
      // AuthGate navigates to MainPage automatically via the household stream.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageControllerProvider);
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(language, 'setup_household')),
        actions: [
          IconButton(
            tooltip: AppStrings.tr(language, 'logout'),
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider).signOut(),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.group_add, size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  language == AppLanguage.tamil
                      ? 'SplitLedger குடும்பம் அல்லது குழுவினருடன் பகிரப்பட்ட செலவுகளை நிர்வகிக்க உதவுகிறது.\nபுதிய குழுவை உருவாக்கவும் அல்லது அழைப்புக் குறியீடு மூலம் இணையவும்.'
                      : 'SplitLedger works between people sharing expenses.\nCreate a household or join your partner\'s.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _isLoading ? null : _createHousehold,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(AppStrings.tr(language, 'create_new_household'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),
                Text(
                  AppStrings.tr(language, 'or_divider'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, color: onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _inviteCodeController,
                  decoration: InputDecoration(
                    labelText: AppStrings.tr(language, 'enter_invite_code'),
                    border: const OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _isLoading ? null : _joinHousehold,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(AppStrings.tr(language, 'join_household'), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
