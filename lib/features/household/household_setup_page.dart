import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Household Created!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this invite code with your partner so they can join:'),
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
            label: const Text('Copy'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: inviteCode));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Invite code copied')),
                );
              }
            },
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _joinHousehold() async {
    if (_inviteCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter invite code')));
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Household'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
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
                const Icon(Icons.group_add, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'SplitLedger works between exactly 2 people.\nCreate a household or join your partner\'s.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _createHousehold,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Create New Household'),
                ),
                const SizedBox(height: 32),
                const Text(
                  'OR',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _inviteCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Invite Code',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _joinHousehold,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Join Household'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
