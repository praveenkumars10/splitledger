import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/categories.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/utils.dart';
import '../../auth/auth_controller.dart';
import '../../household/current_household_provider.dart';
import '../models/recurring_expense_model.dart';
import '../recurring_repository.dart';

class AddEditRecurringDialog extends ConsumerStatefulWidget {
  final RecurringExpenseModel? existingItem;

  const AddEditRecurringDialog({super.key, this.existingItem});

  static Future<void> show(BuildContext context, {RecurringExpenseModel? existingItem}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEditRecurringDialog(existingItem: existingItem),
    );
  }

  @override
  ConsumerState<AddEditRecurringDialog> createState() => _AddEditRecurringDialogState();
}

class _AddEditRecurringDialogState extends ConsumerState<AddEditRecurringDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;

  late String _selectedCategory;
  late int _selectedDueDay;
  String? _selectedPayerUid;
  String? _selectedPayerName;
  bool _isLoading = false;

  final List<String> _quickSuggestions = [
    'House Rent',
    'WiFi / Internet',
    'Electricity Bill',
    'Netflix',
    'Amazon Prime',
    'Gym Membership',
    'Milk Delivery',
    'Car / Bike EMI',
  ];

  @override
  void initState() {
    super.initState();
    final item = widget.existingItem;
    _titleController = TextEditingController(text: item?.title ?? '');
    _amountController = TextEditingController(text: item != null ? item.amount.toStringAsFixed(0) : '');
    _notesController = TextEditingController(text: item?.notes ?? '');
    _selectedCategory = item?.category ?? 'bills';
    _selectedDueDay = item?.dueDay ?? 1;
    _selectedPayerUid = item?.paidByUid;
    _selectedPayerName = item?.paidByName;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final household = ref.read(currentHouseholdProvider).asData?.value;
    if (household == null) return;

    final currentUser = ref.read(authStateChangesProvider).asData?.value;
    final payerUid = _selectedPayerUid ?? currentUser?.uid ?? '';
    final payerName = _selectedPayerName ?? shortName(currentUser?.displayName ?? currentUser?.email ?? 'Me');

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) return;

    setState(() => _isLoading = true);

    final repo = ref.read(recurringRepositoryProvider);

    if (widget.existingItem != null) {
      final updated = widget.existingItem!.copyWith(
        title: _titleController.text.trim(),
        amount: amount,
        category: _selectedCategory,
        dueDay: _selectedDueDay,
        paidByUid: payerUid,
        paidByName: payerName,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      await repo.updateRecurringExpense(household.id, updated);
    } else {
      final newItem = RecurringExpenseModel(
        id: '',
        householdId: household.id,
        title: _titleController.text.trim(),
        amount: amount,
        category: _selectedCategory,
        dueDay: _selectedDueDay,
        paidByUid: payerUid,
        paidByName: payerName,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: DateTime.now(),
      );
      await repo.addRecurringExpense(household.id, newItem);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final household = ref.watch(currentHouseholdProvider).asData?.value;
    final currentUser = ref.watch(authStateChangesProvider).asData?.value;

    final members = household?.members ?? [];
    if (_selectedPayerUid == null && currentUser != null) {
      _selectedPayerUid = currentUser.uid;
      _selectedPayerName = shortName(currentUser.displayName ?? currentUser.email ?? 'Me');
    }

    final isEdit = widget.existingItem != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isEdit ? Icons.edit_calendar_outlined : Icons.calendar_month,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    isEdit
                        ? AppStrings.tr(language, 'edit_recurring')
                        : AppStrings.tr(language, 'add_recurring'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 20),

          // Form body
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  // Suggestions chips (only if adding new)
                  if (!isEdit) ...[
                    Text(
                      'Popular Recurring Expenses',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _quickSuggestions.map((suggestion) {
                        return ActionChip(
                          label: Text(suggestion, style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            setState(() {
                              _titleController.text = suggestion;
                              if (suggestion.contains('Rent')) {
                                _selectedCategory = 'rent';
                              } else if (suggestion.contains('WiFi') || suggestion.contains('Electricity')) {
                                _selectedCategory = 'bills';
                              } else if (suggestion.contains('Netflix') || suggestion.contains('Prime')) {
                                _selectedCategory = 'entertainment';
                              } else if (suggestion.contains('Milk')) {
                                _selectedCategory = 'grocery';
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Title Field
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Title / Service Name',
                      hintText: 'e.g. House Rent, WiFi, Netflix',
                      prefixIcon: const Icon(Icons.receipt_long_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a title' : null,
                  ),
                  const SizedBox(height: 16),

                  // Amount Field
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Amount (₹)',
                      hintText: '0',
                      prefixText: '₹ ',
                      prefixIcon: const Icon(Icons.currency_rupee),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Please enter an amount';
                      final num = double.tryParse(v.trim());
                      if (num == null || num <= 0) return 'Please enter a valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Due Day Selector (Day 1 - 31)
                  Card(
                    elevation: 0.5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${AppStrings.tr(language, 'due_on_day')}: Day $_selectedDueDay',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Monthly on $_selectedDueDay${_getDaySuffix(_selectedDueDay)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Slider(
                            value: _selectedDueDay.toDouble(),
                            min: 1,
                            max: 31,
                            divisions: 30,
                            label: 'Day $_selectedDueDay',
                            onChanged: (val) => setState(() => _selectedDueDay = val.round()),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category Selector
                  Text(
                    'Category',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: appCategories.where((c) => c.id != 'settle').map((cat) {
                      final isSelected = _selectedCategory == cat.id;
                      return ChoiceChip(
                        avatar: Text(cat.emoji, style: const TextStyle(fontSize: 14)),
                        label: Text(cat.getLocalizedName(language), style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        onSelected: (sel) {
                          if (sel) setState(() => _selectedCategory = cat.id);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Paid By Member Selector
                  if (members.isNotEmpty) ...[
                    Text(
                      'Default Payer',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: members.map((m) {
                        final isSelected = _selectedPayerUid == m.uid;
                        return ChoiceChip(
                          avatar: Icon(Icons.person, size: 16, color: isSelected ? Colors.white : colorScheme.primary),
                          label: Text(shortName(m.name)),
                          selected: isSelected,
                          onSelected: (sel) {
                            if (sel) {
                              setState(() {
                                _selectedPayerUid = m.uid;
                                _selectedPayerName = shortName(m.name);
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Notes Field
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: 'Notes / Account # (Optional)',
                      hintText: 'e.g. Account number or bill details',
                      prefixIcon: const Icon(Icons.note_alt_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  offset: const Offset(0, -2),
                  blurRadius: 10,
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: _isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, size: 18),
                  label: Text(
                    isEdit ? AppStrings.tr(language, 'save') : AppStrings.tr(language, 'add_recurring'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _isLoading ? null : _handleSave,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}
