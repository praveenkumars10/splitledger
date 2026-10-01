import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/household_model.dart';
import '../../models/transaction_model.dart';
import '../auth/auth_controller.dart';
import '../household/current_household_provider.dart';
import 'transaction_repository.dart';

class QuickAddBottomSheet extends ConsumerStatefulWidget {
  const QuickAddBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const QuickAddBottomSheet(),
    );
  }

  @override
  ConsumerState<QuickAddBottomSheet> createState() => _QuickAddBottomSheetState();
}

class _QuickAddBottomSheetState extends ConsumerState<QuickAddBottomSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _selectedCategory = 'food';
  TransactionType _type = TransactionType.paid;
  String? _selectedPayerUid;
  bool _isLoading = false;

  final List<(String, IconData, String)> _categories = [
    ('food', Icons.restaurant, 'Food'),
    ('tea', Icons.coffee, 'Tea/Snack'),
    ('fuel', Icons.local_gas_station, 'Fuel'),
    ('grocery', Icons.shopping_cart, 'Grocery'),
    ('rent', Icons.home, 'Rent'),
    ('bills', Icons.receipt_long, 'Bills'),
    ('entertainment', Icons.movie, 'Fun'),
    ('other', Icons.category, 'Other'),
  ];

  final List<int> _quickAmounts = [10, 20, 30, 50, 70, 100, 200, 500];

  void _addQuickAmount(int val) {
    final currentText = _amountController.text.trim();
    final currentVal = double.tryParse(currentText) ?? 0.0;
    final newVal = currentVal + val;
    setState(() {
      _amountController.text = newVal.toStringAsFixed(newVal.truncateToDouble() == newVal ? 0 : 2);
    });
  }

  Future<void> _submit() async {
    final rawAmount = _amountController.text.trim().toLowerCase();
    double? amount;
    if (rawAmount.endsWith('k')) {
      final numPart = double.tryParse(rawAmount.replaceAll('k', '').trim());
      if (numPart != null) amount = numPart * 1000;
    } else {
      amount = double.tryParse(rawAmount);
    }

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    final household = ref.read(currentHouseholdProvider).asData?.value;
    final currentUser = ref.read(authStateChangesProvider).asData?.value;
    if (household == null || currentUser == null) return;

    final payerUid = _selectedPayerUid ?? currentUser.uid;
    final payer = household.members.firstWhere(
      (m) => m.uid == payerUid,
      orElse: () => HouseholdMember(uid: currentUser.uid, name: currentUser.displayName ?? 'You'),
    );

    final note = _noteController.text.trim().isEmpty ? _selectedCategory : _noteController.text.trim();

    setState(() => _isLoading = true);

    try {
      final tx = TransactionModel(
        id: '',
        amount: amount,
        category: _selectedCategory,
        paidByUid: payer.uid,
        paidByName: payer.name,
        note: note,
        date: DateTime.now(),
        type: _type,
        createdAt: DateTime.now(),
      );

      await ref.read(transactionRepositoryProvider).addTransaction(household.id, tx);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚡ Added ${NumberFormat.currency(locale: 'en_IN', symbol: '₹').format(amount)} for $note!'),
            backgroundColor: const Color(0xFF0F766E),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding transaction: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final household = ref.watch(currentHouseholdProvider).asData?.value;
    final currentUser = ref.watch(authStateChangesProvider).asData?.value;
    final members = household?.members ?? [];

    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.bolt, color: Colors.amber, size: 24),
                    SizedBox(width: 8),
                    Text(
                      '1-Tap Quick Expense',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Type selector: Paid (Cash Out) vs Received (Cash In)
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.paid,
                  label: Text('Spend (Cash Out)'),
                  icon: Icon(Icons.arrow_upward, color: Colors.red, size: 16),
                ),
                ButtonSegment(
                  value: TransactionType.received,
                  label: Text('Receive (Cash In)'),
                  icon: Icon(Icons.arrow_downward, color: Colors.green, size: 16),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (set) => setState(() => _type = set.first),
            ),
            const SizedBox(height: 16),

            // Amount Input
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                hintText: '0.00 (e.g. 50 or 2k)',
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 10),

            // Quick Add Chips (+10, +20, +30, +50, +70, +100, +200, +500)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _quickAmounts.map((amt) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ActionChip(
                      label: Text('+$amt', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                      onPressed: () => _addQuickAmount(amt),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Category selector
            const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = _selectedCategory == cat.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ChoiceChip(
                      avatar: Icon(cat.$2, size: 16, color: isSelected ? Colors.white : Colors.black87),
                      label: Text(cat.$3),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) setState(() => _selectedCategory = cat.$1);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Note input
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                hintText: 'Note (Optional, e.g. Lunch at Annapoorna)',
                prefixIcon: const Icon(Icons.edit_note),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 16),

            // Paid By dropdown if multiple members
            if (members.length > 1) ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedPayerUid ?? currentUser?.uid,
                decoration: InputDecoration(
                  labelText: 'Paid By',
                  prefixIcon: const Icon(Icons.person),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
                items: members.map((m) {
                  return DropdownMenuItem(
                    value: m.uid,
                    child: Text(m.uid == currentUser?.uid ? '${m.name} (You)' : m.name),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedPayerUid = val),
              ),
              const SizedBox(height: 20),
            ],

            // Submit Button
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isLoading ? null : _submit,
              icon: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle),
              label: Text(
                _isLoading ? 'Adding...' : '⚡ Quick Save Expense',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}

