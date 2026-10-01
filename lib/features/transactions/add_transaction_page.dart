import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
  late DateTime _selectedDate;
  DateTime? _dueDate;
  bool _isLoading = false;
  HouseholdMember? _selectedUser;
  bool _initialized = false;

  DateTime _calculateNext(DateTime from, RecurrenceInterval interval) {
    switch (interval) {
      case RecurrenceInterval.daily:
        return from.add(const Duration(days: 1));
      case RecurrenceInterval.weekly:
        return from.add(const Duration(days: 7));
      case RecurrenceInterval.biweekly:
        return from.add(const Duration(days: 14));
      case RecurrenceInterval.monthly:
        return DateTime(from.year, from.month + 1, from.day, from.hour, from.minute);
      case RecurrenceInterval.yearly:
        return DateTime(from.year + 1, from.month, from.day, from.hour, from.minute);
      case RecurrenceInterval.none:
        return from;
    }
  }

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
      _selectedDate = tx.date;
      _dueDate = tx.dueDate;
      _selectedRecurrence = tx.recurrence;
      _recurrenceEndDate = tx.recurrenceEndDate;
    } else {
      _selectedDate = DateTime.now();
    }
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
    final amount = double.tryParse(_amountController.text) ?? 0;
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
        category: 'general',
        paidByUid: paidByUser.uid,
        paidByName: paidByUser.name,
        note: _noteController.text.trim(),
        date: _selectedDate,
        dueDate: _dueDate,
        type: widget.type,
        createdAt: _isEditing ? widget.transaction!.createdAt : DateTime.now(),
        splitPercentages: widget.transaction?.splitPercentages,
        splitShares: widget.transaction?.splitShares,
        recurrence: _selectedRecurrence,
        recurrenceEndDate: _recurrenceEndDate,
        nextOccurrence: _selectedRecurrence == RecurrenceInterval.none ? null : _calculateNext(_selectedDate, _selectedRecurrence),
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

    if (!_initialized && household != null && currentUser != null) {
      _selectedUser = household.members.where((m) => m.uid == currentUser.uid).firstOrNull;
      _initialized = true;
    }

    final color = _isPaid ? Colors.red : Colors.green;
    final titleLabel = _isPaid ? 'Who Paid?' : 'Who Received?';
    final amountLabel = _isPaid ? 'Amount Paid' : 'Amount Received';

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Transaction' : 'Add Transaction'),
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
                  // User selection (Read-only)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade50,
                    ),
                    child: Row(
                      children: [
                        Text(titleLabel, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Spacer(),
                        Text(
                          _selectedUser != null ? 'You (${_selectedUser!.name})' : 'You',
                          style: const TextStyle(
                            color: Colors.blue,
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
                      prefixText: '\u20B9 ', // Indian Rupee symbol
                      prefixStyle: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
                      suffixIcon: Icon(Icons.calculate_outlined, color: Colors.blue.shade300),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
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
                      children: [
                        '🍔 Food',
                        '🛒 Groceries',
                        '🚗 Travel',
                        '💡 Bills',
                        '🏠 Rent',
                        '🛍️ Shopping',
                        '💊 Medical',
                        '🎬 Entertainment',
                        '💵 Settle',
                      ].map((tag) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 6.0),
                          child: ActionChip(
                            label: Text(tag, style: const TextStyle(fontSize: 12)),
                            backgroundColor: Colors.grey.shade100,
                            side: BorderSide(color: Colors.grey.shade300),
                            onPressed: () {
                              if (_noteController.text.trim().isEmpty) {
                                _noteController.text = tag;
                              } else if (!_noteController.text.contains(tag)) {
                                _noteController.text = '${_noteController.text} $tag';
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
                      hintText: 'Write notes or category [Optional]',
                      prefixIcon: const Icon(Icons.note_alt_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
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
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Icon(Icons.chevron_left, size: 20),
                                Text(_dateFormat.format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                                const Icon(Icons.chevron_right, size: 20),
                                const Icon(Icons.calendar_today, size: 20, color: Colors.blue),
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
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
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
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_dueDate == null ? 'Due Date' : _dateFormat.format(_dueDate!)),
                          const Icon(Icons.calendar_today, size: 20, color: Colors.blue),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Recurrence Interval Dropdown
                  DropdownButtonFormField<RecurrenceInterval>(
                    initialValue: _selectedRecurrence,
                    decoration: InputDecoration(
                      labelText: 'Repeat',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_recurrenceEndDate == null ? 'End Date (optional)' : _dateFormat.format(_recurrenceEndDate!)),
                            const Icon(Icons.calendar_today, size: 20, color: Colors.blue),
                          ],
                        ),
                      ),
                    ),

                ],
              ),
            ),
          ),
          
          // Bottom Buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue.shade700,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.blue.shade300),
                    ),
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _isLoading ? null : _save,
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(_isEditing ? 'UPDATE' : 'SAVE', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
