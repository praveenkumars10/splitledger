import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/language_controller.dart';
import '../../core/utils.dart';
import '../../models/deleted_audit_item_model.dart';
import 'deleted_history_repository.dart';

class DeletedHistoryPage extends ConsumerStatefulWidget {
  const DeletedHistoryPage({super.key});

  @override
  ConsumerState<DeletedHistoryPage> createState() => _DeletedHistoryPageState();
}

class _DeletedHistoryPageState extends ConsumerState<DeletedHistoryPage> {
  String _selectedFilter = 'all'; // 'all', 'transactions', 'booklets'
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final _currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹');
  final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
  final _shortDateFormat = DateFormat('dd MMM yyyy');

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int _calculateDaysLeft(DateTime deletedAt) {
    final expiryDate = deletedAt.add(DeletedHistoryRepository.retentionPeriod);
    final days = expiryDate.difference(DateTime.now()).inDays;
    return days < 0 ? 0 : days;
  }

  void _showAuditDetailModal(DeletedAuditItemModel item) {
    final language = ref.read(languageControllerProvider);
    final theme = Theme.of(context);
    final isTx = item.type == DeletedItemType.transaction;
    final daysLeft = _calculateDaysLeft(item.deletedAt);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isTx ? Icons.receipt_long : Icons.auto_stories,
                    color: Colors.red.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isTx
                            ? AppStrings.tr(language, 'deleted_item_transaction')
                            : AppStrings.tr(language, 'deleted_item_booklet'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        '${AppStrings.tr(language, 'deleted_on')} ${_dateFormat.format(item.deletedAt)}',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),

            // Deletion Audit Box (Deleter + Cashbook)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_remove_rounded, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${AppStrings.tr(language, 'deleted_by')}:',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.deletedByName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.menu_book_rounded, color: Colors.blueAccent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${AppStrings.tr(language, 'associated_cashbook')}:',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.bookletName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        AppStrings.tr(language, 'auto_purge_days_left').replaceAll('{days}', daysLeft.toString()),
                        style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Item Specific Details
            Text(
              AppStrings.tr(language, 'original_details'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),

            if (isTx) ...[
              _buildDetailRow(
                context,
                'Amount',
                _currencyFormat.format(item.amount ?? 0),
                highlight: true,
                color: item.transactionType == 'received' ? Colors.green : Colors.redAccent,
              ),
              _buildDetailRow(context, 'Category', item.category ?? 'Uncategorized'),
              if (item.note != null && item.note!.isNotEmpty)
                _buildDetailRow(context, 'Note', item.note!),
              if (item.paidByName != null)
                _buildDetailRow(context, 'Paid / Handled By', item.paidByName!),
              if (item.transactionDate != null)
                _buildDetailRow(context, 'Transaction Date', _dateFormat.format(item.transactionDate!)),
              if (item.receiptUrl != null && item.receiptUrl!.isNotEmpty)
                _buildDetailRow(context, 'Receipt', 'Receipt was attached'),
            ] else ...[
              _buildDetailRow(context, 'Cashbook Name', item.bookletName, highlight: true),
              if (item.bookletOpeningBalance != null)
                _buildDetailRow(context, 'Opening Balance', _currencyFormat.format(item.bookletOpeningBalance!)),
              if (item.bookletStartDate != null)
                _buildDetailRow(context, 'Start Date', _shortDateFormat.format(item.bookletStartDate!)),
              if (item.bookletCreatedByName != null)
                _buildDetailRow(context, 'Created By', item.bookletCreatedByName!),
              if (item.transactionCount != null)
                _buildDetailRow(context, 'Transactions Deleted', '${item.transactionCount} items'),
              if (item.totalAmount != null)
                _buildDetailRow(context, 'Total Transactions Amount', _currencyFormat.format(item.totalAmount!)),
            ],

            const SizedBox(height: 20),

            // Tamper-proof notice at bottom of sheet
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_clock_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Audit records are immutable and cannot be edited or manually removed.',
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppStrings.tr(language, 'done')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, {bool highlight = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: highlight ? 15 : 13,
                fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = ref.watch(languageControllerProvider);
    final historyAsync = ref.watch(deletedHistoryStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.tr(language, 'deleted_history')),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: AppStrings.tr(language, 'audit_log_title'),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Row(
                    children: [
                      const Icon(Icons.verified_user_outlined, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Expanded(child: Text(AppStrings.tr(language, 'audit_log_title'))),
                    ],
                  ),
                  content: Text(AppStrings.tr(language, 'audit_log_notice')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(AppStrings.tr(language, 'done')),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading history: $err')),
        data: (allItems) {
          // Filter by category
          final categoryFiltered = allItems.where((item) {
            if (_selectedFilter == 'transactions' && item.type != DeletedItemType.transaction) return false;
            if (_selectedFilter == 'booklets' && item.type != DeletedItemType.booklet) return false;
            return true;
          }).toList();

          // Filter by search query
          final filtered = categoryFiltered.where((item) {
            if (_searchQuery.isEmpty) return true;
            final query = _searchQuery.toLowerCase();
            final deleterMatch = item.deletedByName.toLowerCase().contains(query);
            final bookletMatch = item.bookletName.toLowerCase().contains(query);
            final noteMatch = item.note?.toLowerCase().contains(query) ?? false;
            final catMatch = item.category?.toLowerCase().contains(query) ?? false;
            final amountMatch = item.amount?.toString().contains(query) ?? false;
            return deleterMatch || bookletMatch || noteMatch || catMatch || amountMatch;
          }).toList();

          final txCount = allItems.where((i) => i.type == DeletedItemType.transaction).length;
          final bookletCount = allItems.where((i) => i.type == DeletedItemType.booklet).length;

          return Column(
            children: [
              // 1. Transparency Banner
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, color: theme.colorScheme.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.tr(language, 'audit_log_title'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppStrings.tr(language, 'audit_log_notice'),
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Filter Chips Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('${AppStrings.tr(language, 'filter_all_deleted')} (${allItems.length})'),
                      selected: _selectedFilter == 'all',
                      onSelected: (val) {
                        if (val) setState(() => _selectedFilter = 'all');
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('${AppStrings.tr(language, 'filter_transactions_deleted')} ($txCount)'),
                      selected: _selectedFilter == 'transactions',
                      onSelected: (val) {
                        if (val) setState(() => _selectedFilter = 'transactions');
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('${AppStrings.tr(language, 'filter_booklets_deleted')} ($bookletCount)'),
                      selected: _selectedFilter == 'booklets',
                      onSelected: (val) {
                        if (val) setState(() => _selectedFilter = 'booklets');
                      },
                    ),
                  ],
                ),
              ),

              // 3. Search Bar (if records exist)
              if (allItems.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: AppStrings.tr(language, 'search_hint'),
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  ),
                ),

              const SizedBox(height: 4),

              // 4. List View or Empty State
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.task_alt_rounded, size: 48, color: Colors.green),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                AppStrings.tr(language, 'no_deleted_history'),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                AppStrings.tr(language, 'no_deleted_history_sub'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return _buildAuditCard(context, item);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAuditCard(BuildContext context, DeletedAuditItemModel item) {
    final language = ref.read(languageControllerProvider);
    final theme = Theme.of(context);
    final isTx = item.type == DeletedItemType.transaction;
    final daysLeft = _calculateDaysLeft(item.deletedAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Colors.red.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showAuditDetailModal(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Type, Booklet Badge, Amount/Action
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isTx
                          ? Colors.orange.withValues(alpha: 0.12)
                          : Colors.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isTx ? Icons.receipt_long_rounded : Icons.auto_stories_rounded,
                      size: 20,
                      color: isTx ? Colors.orange.shade800 : Colors.purple.shade700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Booklet pill badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.menu_book_rounded, size: 11, color: Colors.blueAccent),
                                  const SizedBox(width: 4),
                                  Text(
                                    item.bookletName,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            if (isTx && item.amount != null)
                              Text(
                                _currencyFormat.format(item.amount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.redAccent,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Title / Category
                        Text(
                          isTx
                              ? (item.note != null && item.note!.trim().isNotEmpty
                                  ? item.note!
                                  : item.category ?? 'Expense')
                              : '${AppStrings.tr(language, 'deleted_item_booklet')}: "${item.bookletName}"',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isTx) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${item.category ?? "Expense"} • ${item.paidByName != null ? "${AppStrings.tr(language, 'who_paid')}: ${shortName(item.paidByName!)}" : ""} • ${item.transactionDate != null ? _shortDateFormat.format(item.transactionDate!) : ""}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 2),
                          Text(
                            '${item.transactionCount ?? 0} transactions removed • Created by ${item.bookletCreatedByName ?? "Member"}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Deleter & Audit Footer Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${AppStrings.tr(language, 'deleted_by')} ${item.deletedByName} • ${_dateFormat.format(item.deletedAt)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${daysLeft}d left',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

