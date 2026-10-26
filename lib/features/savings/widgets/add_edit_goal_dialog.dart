import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/localization/language_controller.dart';
import '../../household/current_household_provider.dart';
import '../models/savings_goal_model.dart';
import '../savings_repository.dart';

class AddEditGoalDialog extends ConsumerStatefulWidget {
  final SavingsGoalModel? existingGoal;

  const AddEditGoalDialog({super.key, this.existingGoal});

  static Future<void> show(BuildContext context, {SavingsGoalModel? existingGoal}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddEditGoalDialog(existingGoal: existingGoal),
    );
  }

  @override
  ConsumerState<AddEditGoalDialog> createState() => _AddEditGoalDialogState();
}

class _AddEditGoalDialogState extends ConsumerState<AddEditGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _targetController;
  late final TextEditingController _currentController;
  late final TextEditingController _notesController;

  late String _selectedEmoji;
  late int _selectedColor;
  DateTime? _selectedTargetDate;
  bool _isLoading = false;

  final List<String> _emojis = ['🎯', '🏦', '🏖️', '💻', '🏍️', '🚗', '🏠', '🎁', '💍', '📈'];
  final List<int> _colors = [
    0xFF10B981, // Emerald Green
    0xFF3B82F6, // Ocean Blue
    0xFF8B5CF6, // Purple
    0xFFF59E0B, // Amber
    0xFFEC4899, // Pink
    0xFF06B6D4, // Cyan
  ];

  final List<(String, String, int)> _quickGoalPresets = [
    ('Emergency Fund', '🏦', 0xFF10B981),
    ('Vacation Trip', '🏖️', 0xFF06B6D4),
    ('New Laptop', '💻', 0xFF3B82F6),
    ('Bike / Vehicle', '🏍️', 0xFFF59E0B),
    ('Wedding / Gift', '🎁', 0xFFEC4899),
  ];

  @override
  void initState() {
    super.initState();
    final goal = widget.existingGoal;
    _titleController = TextEditingController(text: goal?.title ?? '');
    _targetController = TextEditingController(
      text: goal != null ? goal.targetAmount.toStringAsFixed(0) : '',
    );
    _currentController = TextEditingController(
      text: goal != null && goal.currentAmount > 0 ? goal.currentAmount.toStringAsFixed(0) : '',
    );
    _notesController = TextEditingController(text: goal?.notes ?? '');
    _selectedEmoji = goal?.emoji ?? '🎯';
    _selectedColor = goal?.colorValue ?? 0xFF10B981;
    _selectedTargetDate = goal?.targetDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    _currentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final household = ref.read(currentHouseholdProvider).asData?.value;
    if (household == null) return;

    final target = double.tryParse(_targetController.text.trim()) ?? 0.0;
    if (target <= 0) return;

    final current = double.tryParse(_currentController.text.trim()) ?? 0.0;

    setState(() => _isLoading = true);
    final repo = ref.read(savingsRepositoryProvider);

    if (widget.existingGoal != null) {
      final updated = widget.existingGoal!.copyWith(
        title: _titleController.text.trim(),
        targetAmount: target,
        currentAmount: current,
        targetDate: _selectedTargetDate,
        emoji: _selectedEmoji,
        colorValue: _selectedColor,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      await repo.updateGoal(household.id, updated);
    } else {
      final newGoal = SavingsGoalModel(
        id: '',
        householdId: household.id,
        title: _titleController.text.trim(),
        targetAmount: target,
        currentAmount: current,
        targetDate: _selectedTargetDate,
        emoji: _selectedEmoji,
        colorValue: _selectedColor,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: DateTime.now(),
      );
      await repo.addGoal(household.id, newGoal);
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
    final isEdit = widget.existingGoal != null;

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
                    color: Color(_selectedColor).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(_selectedEmoji, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    isEdit
                        ? AppStrings.tr(language, 'edit_goal')
                        : AppStrings.tr(language, 'add_goal'),
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

          // Form
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  // Presets (only on new)
                  if (!isEdit) ...[
                    Text(
                      'Popular Goals',
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
                      children: _quickGoalPresets.map((preset) {
                        return ActionChip(
                          avatar: Text(preset.$2, style: const TextStyle(fontSize: 14)),
                          label: Text(preset.$1, style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            setState(() {
                              _titleController.text = preset.$1;
                              _selectedEmoji = preset.$2;
                              _selectedColor = preset.$3;
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
                      labelText: 'Goal Title',
                      hintText: 'e.g. Emergency Fund, Goa Trip',
                      prefixIcon: const Icon(Icons.flag_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a goal title' : null,
                  ),
                  const SizedBox(height: 16),

                  // Target Amount Field
                  TextFormField(
                    controller: _targetController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Target Amount (₹)',
                      hintText: 'e.g. 50000',
                      prefixText: '₹ ',
                      prefixIcon: const Icon(Icons.savings_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Please enter target amount';
                      final num = double.tryParse(v.trim());
                      if (num == null || num <= 0) return 'Please enter a valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Current / Initial Saved Amount
                  TextFormField(
                    controller: _currentController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Already Saved Amount (Optional)',
                      hintText: '0',
                      prefixText: '₹ ',
                      prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Emoji Icon Selector
                  Text(
                    'Goal Icon',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: _emojis.map((emoji) {
                      final isSelected = _selectedEmoji == emoji;
                      return InkWell(
                        onTap: () => setState(() => _selectedEmoji = emoji),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected ? colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                            border: Border.all(
                              color: isSelected ? colorScheme.primary : colorScheme.outlineVariant.withValues(alpha: 0.4),
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(emoji, style: const TextStyle(fontSize: 22)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Color Picker
                  Text(
                    'Color Theme',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    children: _colors.map((c) {
                      final isSelected = _selectedColor == c;
                      return InkWell(
                        onTap: () => setState(() => _selectedColor = c),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 3,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: Color(c).withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)]
                                : null,
                          ),
                          child: isSelected ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Target Deadline Date Picker
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('Target Deadline (Optional)', style: TextStyle(fontSize: 14)),
                    subtitle: Text(
                      _selectedTargetDate != null
                          ? DateFormat('dd MMM yyyy').format(_selectedTargetDate!)
                          : 'No deadline set',
                      style: TextStyle(
                        color: _selectedTargetDate != null ? colorScheme.primary : colorScheme.onSurfaceVariant,
                        fontWeight: _selectedTargetDate != null ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: _selectedTargetDate != null
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () => setState(() => _selectedTargetDate = null),
                          )
                        : const Icon(Icons.calendar_today, size: 18),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedTargetDate ?? DateTime.now().add(const Duration(days: 90)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                      );
                      if (picked != null) {
                        setState(() => _selectedTargetDate = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  TextFormField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      labelText: 'Notes / Motivation (Optional)',
                      hintText: 'e.g. Save ₹2,500 every cycle from salary',
                      prefixIcon: const Icon(Icons.notes),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Bottom Action
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
                    isEdit ? AppStrings.tr(language, 'save') : AppStrings.tr(language, 'add_goal'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: Color(_selectedColor),
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
}
