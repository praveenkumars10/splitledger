import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/categories.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/language_controller.dart';
import '../../models/transaction_model.dart';
import '../../models/household_model.dart';
import 'transaction_repository.dart';
import '../auth/auth_controller.dart';
import '../household/current_household_provider.dart';

class AddTransactionPage extends ConsumerStatefulWidget {
  final TransactionType type;
  final TransactionModel? transaction;

  const AddTransactionPage({super.key, this.type = TransactionType.paid, this.transaction});

  @override
  ConsumerState<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends ConsumerState<AddTransactionPage> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _selectedCategory = 'food';
  late DateTime _selectedDate;
  DateTime? _dueDate;
  bool _isLoading = false;
  HouseholdMember? _selectedUser;
  bool _initialized = false;

  // Recurrence state
  RecurrenceInterval _selectedRecurrence = RecurrenceInterval.none;
  DateTime? _recurrenceEndDate;

  final _dateFormat = DateFormat('dd-MMM-yyyy');
  final _timeFormat = DateFormat('hh:mm a');

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  bool get _isPaid => widget.type == TransactionType.paid;
  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    if (tx != null) {
      _amountController.text = tx.amount.toStringAsFixed(tx.amount % 1 == 0 ? 0 : 2);
      _noteController.text = tx.note ?? '';
      _selectedCategory = tx.category.isNotEmpty ? tx.category : 'food';
      _selectedDate = tx.date;
      _dueDate = tx.dueDate;
      _selectedRecurrence = tx.recurrence;
      _recurrenceEndDate = tx.recurrenceEndDate;
    } else {
      _selectedDate = DateTime.now();
    }
  }

  void _selectCategory(AppCategory cat, AppLanguage language) {
    final catName = cat.getLocalizedName(language);
    final tag = '${cat.emoji} $catName';
    setState(() {
      _selectedCategory = cat.id;
      final currentNote = _noteController.text.trim();
      if (currentNote.isEmpty) {
        _noteController.text = tag;
      } else {
        bool isOnlyCategoryTag = false;
        for (final otherCat in appCategories) {
          final otherTag = '${otherCat.emoji} ${otherCat.getLocalizedName(language)}';
          if (currentNote == otherTag || currentNote == otherCat.getLocalizedName(language)) {
            isOnlyCategoryTag = true;
            break;
          }
        }
        if (isOnlyCategoryTag) {
          _noteController.text = tag;
        } else if (!currentNote.contains(tag) && !currentNote.contains(cat.emoji)) {
          _noteController.text = '$tag $currentNote';
        }
      }
    });
  }

  void _removeCategory(AppCategory cat, AppLanguage language) {
    final catName = cat.getLocalizedName(language);
    final tag = '${cat.emoji} $catName';
    setState(() {
      String updated = _noteController.text;
      updated = updated.replaceAll(tag, '');
      updated = updated.replaceAll(cat.emoji, '');
      updated = updated.replaceAll(catName, '');
      updated = updated.replaceAll(RegExp(r'\s+'), ' ').trim();
      _noteController.text = updated;
      if (_selectedCategory == cat.id) {
        _selectedCategory = 'other';
      }
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  void _save() async {
    final cleanText = _amountController.text.trim().replaceAll(',', '');
    final amount = double.tryParse(cleanText) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final household = ref.read(currentHouseholdProvider).asData?.value;
      final user = ref.read(authStateChangesProvider).asData?.value;

      if (household == null || user == null) throw Exception('Not logged in or no household');

      final paidByUser = _selectedUser ?? household.members.where((m) => m.uid == user.uid).firstOrNull;
      if (paidByUser == null) throw Exception('Selected user not found');

      final tx = TransactionModel(
        id: _isEditing ? widget.transaction!.id : '',
        amount: amount,
        category: _selectedCategory,
        paidByUid: paidByUser.uid,
        paidByName: paidByUser.name,
        note: _noteController.text.trim().isEmpty ? _selectedCategory : _noteController.text.trim(),
        date: _selectedDate,
        dueDate: _dueDate,
        type: widget.type,
        createdAt: _isEditing ? widget.transaction!.createdAt : DateTime.now(),
        splitPercentages: widget.transaction?.splitPercentages,
        splitShares: widget.transaction?.splitShares,
        recurrence: _selectedRecurrence,
        recurrenceEndDate: _recurrenceEndDate,
        nextOccurrence: _selectedRecurrence == RecurrenceInterval.none ? null : TransactionModel.calculateNextOccurrence(_selectedDate, _selectedRecurrence),
      );

      if (_isEditing) {
        await ref.read(transactionRepositoryProvider).updateTransaction(household.id, tx);
      } else {
        await ref.read(transactionRepositoryProvider).addTransaction(household.id, tx);
      }

      if (mounted) Navigator.of(context).pop();
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
    final household = ref.watch(currentHouseholdProvider).asData?.value;
    final currentUser = ref.watch(authStateChangesProvider).asData?.value;
    final language = ref.watch(languageControllerProvider);

    if (!_initialized && household != null && currentUser != null) {
      _selectedUser = household.members.where((m) => m.uid == currentUser.uid).firstOrNull;
      _initialized = true;
    }

    final color = _isPaid ? Colors.red : Colors.green;
    final titleLabel = AppStrings.tr(language, _isPaid ? 'who_paid' : 'who_received');
    final amountLabel = AppStrings.tr(language, _isPaid ? 'amount_paid' : 'amount_received');

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(language, _isEditing ? 'edit_transaction' : 'add_transaction')),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // User selection
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).cardColor,
                    ),
                    child: Row(
                      children: [
                        Text(titleLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Spacer(),
                        Text(
                          _selectedUser != null
                              ? '${AppStrings.tr(language, 'you')} (${_selectedUser!.name})'
                              : AppStrings.tr(language, 'you'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Amount Input
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
                    decoration: InputDecoration(
                      labelText: amountLabel,
                      labelStyle: TextStyle(color: color),
                      prefixText: '₹ ',
                      prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
                      suffixIcon: Icon(Icons.calculate_outlined, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: color, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Quick Amount Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [10, 20, 30, 50, 70, 100, 200, 500, 1000, 2000, 5000].map((addAmount) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ActionChip(
                            label: Text('+₹$addAmount', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            backgroundColor: color.withValues(alpha: 0.08),
                            side: BorderSide(color: color.withValues(alpha: 0.3)),
                            onPressed: () {
                              final current = double.tryParse(_amountController.text) ?? 0;
                              final next = current + addAmount;
                              _amountController.text = next.toStringAsFixed(next % 1 == 0 ? 0 : 2);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quick Category Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: appCategories.map((cat) {
                        final catName = cat.getLocalizedName(language);
                        final tag = '${cat.emoji} $catName';
                        final isSelected = _selectedCategory == cat.id &&
                            (_noteController.text.contains(tag) ||
                             _noteController.text.contains(cat.emoji) ||
                             _noteController.text.contains(catName));
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: InputChip(
                            avatar: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: cat.color.withValues(alpha: isSelected ? 0.25 : 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(cat.icon, size: 14, color: cat.color),
                            ),
                            label: Text(
                              tag,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: cat.color.withValues(alpha: 0.18),
                            backgroundColor: Theme.of(context).cardColor,
                            side: BorderSide(
                              color: isSelected ? cat.color : Theme.of(context).dividerColor,
                              width: isSelected ? 1.5 : 1,
                            ),
                            deleteIcon: isSelected ? Icon(Icons.cancel, size: 16, color: cat.color) : null,
                            deleteButtonTooltipMessage: 'Remove $catName',
                            onDeleted: isSelected ? () => _removeCategory(cat, language) : null,
                            onSelected: (selected) {
                              if (selected) {
                                _selectCategory(cat, language);
                              } else {
                                _removeCategory(cat, language);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Notes Input
                  TextField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      hintText: AppStrings.tr(language, 'note_optional_hint'),
                      prefixIcon: const Icon(Icons.note_alt_outlined),
                      suffixIcon: _noteController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              tooltip: 'Clear note',
                              onPressed: () {
                                setState(() {
                                  _noteController.clear();
                                  _selectedCategory = 'other';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),

                  // Date and Time
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: InkWell(
                          onTap: () => _selectDate(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Theme.of(context).dividerColor),
                              borderRadius: BorderRadius.circular(12),
                              color: Theme.of(context).cardColor,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Icon(Icons.chevron_left, size: 20),
                                Text(_dateFormat.format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                                const Icon(Icons.chevron_right, size: 20),
                                Icon(Icons.calendar_today, size: 20, color: Theme.of(context).colorScheme.primary),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: InkWell(
                          onTap: () => _selectTime(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Theme.of(context).dividerColor),
                              borderRadius: BorderRadius.circular(12),
                              color: Theme.of(context).cardColor,
                            ),
                            child: Center(
                              child: Text(_timeFormat.format(_selectedDate)),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Due Date
                  InkWell(
                    onTap: () => _selectDueDate(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).cardColor,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_dueDate == null ? AppStrings.tr(language, 'due_date') : _dateFormat.format(_dueDate!)),
                          Icon(Icons.calendar_today, size: 20, color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Recurrence Interval Dropdown
                  DropdownButtonFormField<RecurrenceInterval>(
                    initialValue: _selectedRecurrence,
                    decoration: InputDecoration(
                      labelText: AppStrings.tr(language, 'repeat'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: RecurrenceInterval.values
                        .map((i) => DropdownMenuItem(value: i, child: Text(i.toString().split('.').last)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedRecurrence = v ?? RecurrenceInterval.none),
                  ),
                  const SizedBox(height: 16),

                  // Recurrence End Date (optional)
                  if (_selectedRecurrence != RecurrenceInterval.none)
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _recurrenceEndDate ?? DateTime.now(),
                          firstDate: _selectedDate,
                          lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                        );
                        if (picked != null) setState(() => _recurrenceEndDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(12),
                          color: Theme.of(context).cardColor,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_recurrenceEndDate == null ? AppStrings.tr(language, 'end_date_optional') : _dateFormat.format(_recurrenceEndDate!)),
                            Icon(Icons.calendar_today, size: 20, color: Theme.of(context).colorScheme.primary),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom Buttons
          SafeArea(
            top: false,
            bottom: true,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: Text(
                        AppStrings.tr(language, 'cancel').toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isLoading ? null : _save,
                      child: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              AppStrings.tr(language, _isEditing ? 'update' : 'save').toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
