import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_strings.dart';
import '../../../core/localization/language_controller.dart';
import '../../../core/preferences/app_preferences.dart';
import '../../auth/auth_controller.dart';
import '../../household/current_household_provider.dart';
import '../booklet_repository.dart';

class BookletSelectorBar extends ConsumerWidget {
  final bool compact;
  const BookletSelectorBar({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageControllerProvider);
    final activeBooklet = ref.watch(activeBookletProvider);
    final filter = ref.watch(selectedBookletFilterProvider);
    final isAll = filter == 'ALL';

    final label = isAll
        ? AppStrings.tr(language, 'all_booklets')
        : (activeBooklet?.name ?? AppStrings.tr(language, 'booklet'));

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => showBookletSwitchSheet(context),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: compact ? 4 : 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAll ? Icons.all_inbox_rounded : Icons.menu_book_rounded,
              size: compact ? 15 : 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (activeBooklet?.isClosed == true && !isAll) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  AppStrings.tr(language, 'closed_badge'),
                  style: const TextStyle(fontSize: 9, color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: compact ? 16 : 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showBookletSwitchSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => const _BookletSwitchBottomSheet(),
  );
}

class _BookletSwitchBottomSheet extends ConsumerWidget {
  const _BookletSwitchBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageControllerProvider);
    final bookletsAsync = ref.watch(bookletsStreamProvider);
    final activeBooklet = ref.watch(activeBookletProvider);
    final filter = ref.watch(selectedBookletFilterProvider);
    final dateFormat = DateFormat('dd MMM yyyy');

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.auto_stories, color: Colors.blueAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppStrings.tr(language, 'select_booklet'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: bookletsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (booklets) {
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      // All Booklets Option
                      ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        selected: filter == 'ALL',
                        selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blueGrey.withValues(alpha: 0.15),
                          child: const Icon(Icons.all_inbox_rounded, color: Colors.blueGrey),
                        ),
                        title: Text(
                          AppStrings.tr(language, 'all_booklets'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: const Text('View and split all household transactions'),
                        trailing: filter == 'ALL'
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : null,
                        onTap: () {
                          ref.read(selectedBookletFilterProvider.notifier).setFilter('ALL');
                          Navigator.of(context).pop();
                        },
                      ),
                      const SizedBox(height: 6),
                      if (booklets.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Center(
                            child: Text(
                              'Default Cashbook is active.\nTap "+ Start New Booklet" below to organize your transactions into trips or periods!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                            ),
                          ),
                        ),
                      ...booklets.map((booklet) {
                        final isSelected = filter != 'ALL' && activeBooklet?.id == booklet.id;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).dividerColor.withValues(alpha: 0.2),
                              width: isSelected ? 1.5 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.15)
                                : null,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: booklet.isClosed
                                  ? Colors.grey.withValues(alpha: 0.2)
                                  : Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                              child: Icon(
                                booklet.isClosed ? Icons.folder_zip_rounded : Icons.menu_book_rounded,
                                color: booklet.isClosed ? Colors.grey : Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    booklet.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: booklet.isClosed ? Colors.grey : null,
                                    ),
                                  ),
                                ),
                                if (booklet.isClosed)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      AppStrings.tr(language, 'closed_badge'),
                                      style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: Text(
                              'Started ${dateFormat.format(booklet.startDate)}'
                              '${booklet.endDate != null ? ' • Closed ${dateFormat.format(booklet.endDate!)}' : ''}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : const Icon(Icons.chevron_right, size: 18),
                            onTap: () async {
                              final household = ref.read(currentHouseholdProvider).asData?.value;
                              ref.read(selectedBookletFilterProvider.notifier).setFilter(booklet.id);
                              if (household != null) {
                                await ref.read(bookletRepositoryProvider).setActiveBooklet(household.id, booklet.id);
                              }
                              await ref.read(appPreferencesProvider.notifier).setActiveBookletId(booklet.id);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${AppStrings.tr(language, 'booklet_switched')} "${booklet.name}"'),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add),
              label: Text(
                AppStrings.tr(language, 'start_new_booklet'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                showCreateBookletDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showCreateBookletDialog(BuildContext context) {
  return showDialog(
    context: context,
    builder: (ctx) => const _CreateBookletDialog(),
  );
}

class _CreateBookletDialog extends ConsumerStatefulWidget {
  const _CreateBookletDialog();

  @override
  ConsumerState<_CreateBookletDialog> createState() => _CreateBookletDialogState();
}

class _CreateBookletDialogState extends ConsumerState<_CreateBookletDialog> {
  final _nameController = TextEditingController();
  final _openingBalanceController = TextEditingController();
  final _noteController = TextEditingController();
  late DateTime _startDate;
  bool _isLoading = false;

  final _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _startDate = DateTime.now();
    _nameController.text = 'Cashbook - ${DateFormat('dd MMM').format(_startDate)}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _openingBalanceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _handleCreate() async {
    final language = ref.read(languageControllerProvider);
    final household = ref.read(currentHouseholdProvider).asData?.value;
    final currentUser = ref.read(authStateChangesProvider).asData?.value;

    if (household == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Household not found.')),
      );
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.tr(language, 'booklet_name'))),
      );
      return;
    }

    final openingBalance = double.tryParse(_openingBalanceController.text.trim()) ?? 0.0;

    setState(() => _isLoading = true);
    try {
      final booklet = await ref.read(bookletRepositoryProvider).createBooklet(
            householdId: household.id,
            name: name,
            startDate: _startDate,
            createdByUid: currentUser?.uid ?? '',
            createdByName: currentUser?.displayName ?? 'Member',
            openingBalance: openingBalance,
            note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          );

      ref.read(selectedBookletFilterProvider.notifier).setFilter(booklet.id);
      await ref.read(appPreferencesProvider.notifier).setActiveBookletId(booklet.id);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.tr(language, 'booklet_saved')),
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

    final presets = ['Daily Cashbook', 'Trip', 'Project', 'Home Expense'];

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.menu_book_rounded, color: Colors.blue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppStrings.tr(language, 'start_new_booklet'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
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
              'A new cashbook will hold and group all transactions starting from this date for clean splits and reports.',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: AppStrings.tr(language, 'booklet_name'),
                hintText: AppStrings.tr(language, 'booklet_name_hint'),
                prefixIcon: const Icon(Icons.edit_note),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: presets.map((p) {
                return ActionChip(
                  label: Text(p, style: const TextStyle(fontSize: 11)),
                  onPressed: () {
                    setState(() {
                      _nameController.text = '$p - ${_dateFormat.format(_startDate)}';
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickStartDate,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: AppStrings.tr(language, 'start_date'),
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: const OutlineInputBorder(),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_dateFormat.format(_startDate), style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Icon(Icons.edit_calendar, size: 18, color: Colors.blue),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _openingBalanceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: AppStrings.tr(language, 'opening_balance'),
                hintText: '0.00',
                prefixIcon: const Icon(Icons.currency_rupee),
                border: const OutlineInputBorder(),
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
          onPressed: _isLoading ? null : _handleCreate,
          child: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(AppStrings.tr(language, 'create_booklet')),
        ),
      ],
    );
  }
}
