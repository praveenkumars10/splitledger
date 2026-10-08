import '../models/transaction_model.dart';

/// Represents one settlement transaction from [from] to [to].
class SettlementTransaction {
  final String from;
  final String to;
  final double amount;
  final String fromUid;
  final String toUid;

  const SettlementTransaction({
    required this.from,
    required this.to,
    required this.amount,
    this.fromUid = '',
    this.toUid = '',
  });

  @override
  String toString() => '$from -> $to: Rs.${amount.toStringAsFixed(2)}';
}

/// Per-member balance summary used for settlement.
class MemberBalance {
  final String uid;
  final String name;
  final double paid;
  final double share;
  double get net => paid - share;

  const MemberBalance({required this.uid, required this.name, required this.paid, required this.share});
}

/// Result of a group split calculation.
class GroupSplitResult {
  final double totalExpense;
  final int memberCount;
  final double individualShare;
  final List<MemberBalance> balances;
  final List<SettlementTransaction> settlements;

  const GroupSplitResult({
    required this.totalExpense,
    required this.memberCount,
    required this.individualShare,
    required this.balances,
    required this.settlements,
  });

  bool get isSettled => settlements.isEmpty;

  /// Verifies that the sum of all net balances is zero (within rounding tolerance).
  bool get balancesSumToZero => balances.fold<double>(0, (sum, b) => sum + b.net).abs() < 0.01;

  /// Verifies that total owed equals total to be received.
  bool get settlementAmountsMatch {
    final totalOwed = balances.where((b) => b.net < 0).fold<double>(0, (sum, b) => sum + b.net.abs());
    final totalReceived = balances.where((b) => b.net > 0).fold<double>(0, (sum, b) => sum + b.net);
    return (totalOwed - totalReceived).abs() < 0.01;
  }
}

/// Calculates equal or custom splits for any number of members.
GroupSplitResult calculateGroupSplit({
  required List<TransactionModel> transactions,
  required List<({String uid, String name})> members,
}) {
  if (members.isEmpty) {
    return const GroupSplitResult(totalExpense: 0, memberCount: 0, individualShare: 0, balances: [], settlements: []);
  }

  final paidMap = <String, double>{for (final m in members) m.uid: 0};
  final shareMap = <String, double>{for (final m in members) m.uid: 0};
  double totalExpense = 0;

  for (final tx in transactions) {
    if (tx.type == TransactionType.paid) {
      totalExpense += tx.amount;
      paidMap[tx.paidByUid] = (paidMap[tx.paidByUid] ?? 0) + tx.amount;

      final txShares = _transactionShares(tx, members);
      for (final e in txShares.entries) {
        shareMap[e.key] = (shareMap[e.key] ?? 0) + e.value;
      }
    } else if (tx.type == TransactionType.received) {
      // Treat "received" as an internal settlement.
      if (tx.counterpartyUid != null && tx.counterpartyUid!.isNotEmpty && paidMap.containsKey(tx.counterpartyUid)) {
        // Direct settlement: receiver (paidByUid) drops, payer (counterpartyUid) gains credit
        paidMap[tx.paidByUid] = (paidMap[tx.paidByUid] ?? 0) - tx.amount;
        paidMap[tx.counterpartyUid!] = (paidMap[tx.counterpartyUid!] ?? 0) + tx.amount;
      } else {
        // Fallback for general received or 2-member group:
        paidMap[tx.paidByUid] = (paidMap[tx.paidByUid] ?? 0) - tx.amount;

        final otherMembers = members.where((m) => m.uid != tx.paidByUid).toList();
        if (otherMembers.isNotEmpty) {
          final splitPayment = tx.amount / otherMembers.length;
          for (final m in otherMembers) {
            paidMap[m.uid] = (paidMap[m.uid] ?? 0) + splitPayment;
          }
        } else {
          // Fallback for 1-person group: just reduce total expense.
          totalExpense -= tx.amount;
          shareMap[tx.paidByUid] = (shareMap[tx.paidByUid] ?? 0) - tx.amount;
        }
      }
    }
  }

  final balances = members
      .map((m) => MemberBalance(uid: m.uid, name: m.name, paid: paidMap[m.uid] ?? 0, share: shareMap[m.uid] ?? 0))
      .toList();

  return GroupSplitResult(
    totalExpense: totalExpense,
    memberCount: members.length,
    individualShare: totalExpense / members.length,
    balances: balances,
    settlements: _minimizeSettlements(balances),
  );
}

/// Calculates each member's share for a single transaction.
Map<String, double> _transactionShares(TransactionModel tx, List<({String uid, String name})> members) {
  final amount = tx.type == TransactionType.paid ? tx.amount : -tx.amount;
  final shares = <String, double>{};

  // Custom percentages.
  if (tx.splitPercentages != null && tx.splitPercentages!.isNotEmpty) {
    final totalPct = tx.splitPercentages!.values.fold<double>(0, (sum, v) => sum + v);
    if ((totalPct - 100).abs() < 0.01) {
      for (final m in members) {
        shares[m.uid] = amount * (tx.splitPercentages![m.uid] ?? 0) / 100;
      }
      return shares;
    }
  }

  // Custom share weights.
  if (tx.splitShares != null && tx.splitShares!.isNotEmpty) {
    final total = tx.splitShares!.values.fold<double>(0, (sum, v) => sum + v);
    if (total > 0) {
      for (final m in members) {
        shares[m.uid] = amount * (tx.splitShares![m.uid] ?? 0) / total;
      }
      return shares;
    }
  }

  // Equal split.
  final equal = amount / members.length;
  for (final m in members) {
    shares[m.uid] = equal;
  }
  return shares;
}

/// Greedy settlement minimization.
List<SettlementTransaction> _minimizeSettlements(List<MemberBalance> balances) {
  final debtors = balances.where((b) => b.net < -0.001).toList();
  final creditors = balances.where((b) => b.net > 0.001).toList();

  debtors.sort((a, b) => a.net.abs().compareTo(b.net.abs()));
  creditors.sort((a, b) => b.net.compareTo(a.net));

  final settlements = <SettlementTransaction>[];
  int i = 0, j = 0;

  while (i < debtors.length && j < creditors.length) {
    final debt = debtors[i].net.abs();
    final credit = creditors[j].net;
    if (debt < 0.001 || credit < 0.001) break;

    final amount = debt < credit ? debt : credit;
    settlements.add(SettlementTransaction(
      from: debtors[i].name,
      to: creditors[j].name,
      amount: amount,
      fromUid: debtors[i].uid,
      toUid: creditors[j].uid,
    ));

    // Debtor pays their debt -> their share decreases, creditor's share increases.
    final newDebtorShare = debtors[i].share - amount;
    final newCreditorShare = creditors[j].share + amount;
    debtors[i] = MemberBalance(uid: debtors[i].uid, name: debtors[i].name, paid: debtors[i].paid, share: newDebtorShare);
    creditors[j] = MemberBalance(
      uid: creditors[j].uid,
      name: creditors[j].name,
      paid: creditors[j].paid,
      share: newCreditorShare,
    );

    if (debtors[i].net.abs() < 0.001) i++;
    if (creditors[j].net.abs() < 0.001) j++;
  }

  return settlements;
}

/// Formats a settlement message for the current user in a 2-member household.
String formatTwoPersonSettlementMessage({
  required GroupSplitResult result,
  required String currentUserId,
  required String partnerName,
}) {
  final myBalance = result.balances.firstWhere(
    (b) => b.uid == currentUserId,
    orElse: () => const MemberBalance(uid: '', name: 'You', paid: 0, share: 0),
  );

  if (myBalance.net.abs() < 0.01) return 'No due. You are all settled up!';
  if (myBalance.net > 0) return '$partnerName owes you Rs.${myBalance.net.toStringAsFixed(0)}';
  return 'You owe $partnerName Rs.${myBalance.net.abs().toStringAsFixed(0)}';
}
