import 'package:flutter_test/flutter_test.dart';
import 'package:split_ledger/models/booklet_model.dart';
import 'package:split_ledger/models/transaction_model.dart';
import 'package:split_ledger/core/date_filters.dart';
import 'package:split_ledger/core/group_split_calculator.dart';

void main() {
  group('Cashbook-Specific Wallet & Combined Group Wallet Tests', () {
    test('BookletModel stores and retrieves member wallets independently', () {
      final bookletA = BookletModel(
        id: 'booklet_main',
        name: 'Main Cashbook',
        startDate: DateTime(2026, 1, 1),
        createdByUid: 'user_1',
        createdByName: 'Praveen',
        createdAt: DateTime(2026, 1, 1),
        memberWallets: {
          'user_1': 2000.0,
          'user_2': 2000.0,
        },
      );

      final bookletB = BookletModel(
        id: 'booklet_trip',
        name: 'Goa Trip',
        startDate: DateTime(2026, 11, 1),
        createdByUid: 'user_1',
        createdByName: 'Praveen',
        createdAt: DateTime(2026, 11, 1),
        memberWallets: {
          'user_1': 1000.0,
          'user_2': 1500.0,
        },
      );

      // Verify Booklet A values
      expect(bookletA.getMemberWallet('user_1'), 2000.0);
      expect(bookletA.getMemberWallet('user_2'), 2000.0);
      expect(bookletA.totalWalletAmount, 4000.0);

      // Verify Booklet B values are completely isolated and not overwritten
      expect(bookletB.getMemberWallet('user_1'), 1000.0);
      expect(bookletB.getMemberWallet('user_2'), 1500.0);
      expect(bookletB.totalWalletAmount, 2500.0);

      // Verify Booklet A remained unchanged
      expect(bookletA.getMemberWallet('user_1'), 2000.0);
    });

    test('All view calculates combined wallet amount and group spend', () {
      final booklet = BookletModel(
        id: 'booklet_home',
        name: 'Home Cashbook',
        startDate: DateTime(2026, 1, 1),
        createdByUid: 'user_1',
        createdByName: 'Praveen',
        createdAt: DateTime(2026, 1, 1),
        memberWallets: {
          'user_1': 2000.0,
          'user_2': 2000.0,
        },
      );

      final transactions = [
        TransactionModel(
          id: 'tx_1',
          amount: 800.0,
          category: 'Groceries',
          paidByUid: 'user_1',
          paidByName: 'Praveen',
          date: DateTime(2026, 11, 2),
          createdAt: DateTime(2026, 11, 2),
          bookletId: 'booklet_home',
        ),
        TransactionModel(
          id: 'tx_2',
          amount: 700.0,
          category: 'Dining',
          paidByUid: 'user_2',
          paidByName: 'Karthik',
          date: DateTime(2026, 11, 3),
          createdAt: DateTime(2026, 11, 3),
          bookletId: 'booklet_home',
        ),
      ];

      // 1. ALL transactions view
      final allFiltered = filterTransactions(
        transactions,
        timeFilter: 'All',
        userFilter: 'all',
        currentUserId: 'user_1',
      );
      final totalPaidAll = allFiltered.fold(0.0, (sum, t) => sum + t.amount);
      expect(totalPaidAll, 1500.0);

      // Combined wallet is 2000 + 2000 = 4000
      final totalWalletAll = booklet.totalWalletAmount;
      expect(totalWalletAll, 4000.0);

      // Remaining combined balance = 4000 - 1500 = 2500
      final remainingBalanceAll = totalWalletAll - totalPaidAll;
      expect(remainingBalanceAll, 2500.0);

      // 2. User 1 ("Me") view
      final user1Filtered = filterTransactions(
        transactions,
        timeFilter: 'All',
        userFilter: 'me',
        currentUserId: 'user_1',
      );
      final totalPaidUser1 = user1Filtered.fold(0.0, (sum, t) => sum + t.amount);
      expect(totalPaidUser1, 800.0);

      final walletUser1 = booklet.getMemberWallet('user_1');
      expect(walletUser1, 2000.0);

      final remainingBalanceUser1 = walletUser1 - totalPaidUser1;
      expect(remainingBalanceUser1, 1200.0);

      // 3. User 2 ("Partner") view
      final user2Filtered = filterTransactions(
        transactions,
        timeFilter: 'All',
        userFilter: 'user_2',
        currentUserId: 'user_1',
      );
      final totalPaidUser2 = user2Filtered.fold(0.0, (sum, t) => sum + t.amount);
      expect(totalPaidUser2, 700.0);

      final walletUser2 = booklet.getMemberWallet('user_2');
      expect(walletUser2, 2000.0);

      final remainingBalanceUser2 = walletUser2 - totalPaidUser2;
      expect(remainingBalanceUser2, 1300.0);

      // Check sum of individual balances matches combined balance: 1200 + 1300 = 2500
      expect(remainingBalanceUser1 + remainingBalanceUser2, remainingBalanceAll);
    });

    test('BookletModel toMap and fromMap serialization preserves memberWallets', () {
      final booklet = BookletModel(
        id: 'booklet_ser',
        name: 'Office Project',
        startDate: DateTime(2026, 11, 4),
        createdByUid: 'u_1',
        createdByName: 'Alice',
        createdAt: DateTime(2026, 11, 4),
        memberWallets: {
          'u_1': 3500.0,
          'u_2': 4200.0,
          'u_3': 1000.0,
        },
      );

      final map = booklet.toMap();
      expect(map['memberWallets'], isA<Map<String, double>>());
      expect(map['memberWallets']['u_1'], 3500.0);

      final reconstructed = BookletModel.fromMap(map, 'booklet_ser');
      expect(reconstructed.id, 'booklet_ser');
      expect(reconstructed.memberWallets['u_1'], 3500.0);
      expect(reconstructed.memberWallets['u_2'], 4200.0);
      expect(reconstructed.memberWallets['u_3'], 1000.0);
      expect(reconstructed.totalWalletAmount, 8700.0);
    });

    test('Fallback to openingBalance when memberWallets is empty', () {
      final booklet = BookletModel(
        id: 'booklet_legacy',
        name: 'Old Booklet',
        startDate: DateTime(2026, 5, 1),
        createdByUid: 'creator_uid',
        createdByName: 'Legacy User',
        createdAt: DateTime(2026, 5, 1),
        openingBalance: 1500.0,
      );

      expect(booklet.totalWalletAmount, 1500.0);
      expect(booklet.getMemberWallet('creator_uid'), 1500.0);
      expect(booklet.getMemberWallet('other_uid'), 0.0);
    });

    test('Booklet wallet isolation across multiple booklets and aggregation in ALL view', () {
      final booklet1 = BookletModel(
        id: 'bk_1',
        name: 'Household Cashbook',
        startDate: DateTime(2026, 1, 1),
        createdByUid: 'user_1',
        createdByName: 'User 1',
        createdAt: DateTime(2026, 1, 1),
        memberWallets: {
          'user_1': 2000.0,
          'user_2': 2000.0,
        },
      );

      final booklet2 = BookletModel(
        id: 'bk_2',
        name: 'Trip Cashbook',
        startDate: DateTime(2026, 11, 1),
        createdByUid: 'user_1',
        createdByName: 'User 1',
        createdAt: DateTime(2026, 11, 1),
        memberWallets: {
          'user_1': 1000.0,
          'user_2': 1000.0,
        },
      );

      final allBooklets = [booklet1, booklet2];

      // In Booklet 1: user_1 wallet is 2000, total is 4000
      expect(booklet1.getMemberWallet('user_1'), 2000.0);
      expect(booklet1.totalWalletAmount, 4000.0);

      // In Booklet 2: user_1 wallet is 1000, total is 2000 (NOT changed to 2000)
      expect(booklet2.getMemberWallet('user_1'), 1000.0);
      expect(booklet2.totalWalletAmount, 2000.0);

      // In ALL view:
      // user_1 wallet across all booklets = 2000 + 1000 = 3000
      final allUser1Wallet = allBooklets.fold(0.0, (acc, b) => acc + b.getMemberWallet('user_1'));
      expect(allUser1Wallet, 3000.0);

      // Total combined wallet across all booklets = 4000 + 2000 = 6000
      final allTotalWallet = allBooklets.fold(0.0, (acc, b) => acc + b.totalWalletAmount);
      expect(allTotalWallet, 6000.0);
    });

    test('User bookletWallets map fallback functions properly', () {
      final booklet = BookletModel(
        id: 'bk_new',
        name: 'Newly Created Cashbook',
        startDate: DateTime(2026, 11, 4),
        createdByUid: 'user_1',
        createdByName: 'User 1',
        createdAt: DateTime(2026, 11, 4),
        memberWallets: {}, // doc not yet updated
      );

      final userBookletWallets = {
        'bk_new': 1250.0,
      };

      expect(booklet.getMemberWallet('user_1', userBookletWallets: userBookletWallets), 1250.0);
      expect(booklet.getTotalWalletAmount(userBookletWallets: userBookletWallets, currentUid: 'user_1'), 1250.0);
    });

    test('Transactions transferred to target booklet all receive target bookletId', () {
      final txList = [
        TransactionModel(
          id: 'tx_1',
          amount: 500.0,
          category: 'Food',
          paidByUid: 'user_1',
          paidByName: 'User 1',
          date: DateTime.now(),
          createdAt: DateTime.now(),
          bookletId: 'old_booklet_1',
        ),
        TransactionModel(
          id: 'tx_2',
          amount: 1200.0,
          category: 'Shopping',
          paidByUid: 'user_2',
          paidByName: 'User 2',
          date: DateTime.now(),
          createdAt: DateTime.now(),
          bookletId: null, // untagged legacy
        ),
      ];

      const targetBookletId = 'target_booklet';
      final transferred = txList.map((tx) => tx.copyWith(bookletId: targetBookletId)).toList();

      for (final tx in transferred) {
        expect(tx.bookletId, targetBookletId);
      }
      expect(transferred.length, 2);
    });

    test('Cashbook data isolation strictly separates transactions by bookletId', () {
      final txOldBooklet = TransactionModel(
        id: 'tx_old1',
        amount: 300.0,
        category: 'Food',
        paidByUid: 'user_1',
        paidByName: 'User 1',
        date: DateTime.now(),
        createdAt: DateTime.now(),
        bookletId: 'old', // Saved to 'old' booklet
      );

      final txMainBooklet = TransactionModel(
        id: 'tx_main1',
        amount: 700.0,
        category: 'Groceries',
        paidByUid: 'user_2',
        paidByName: 'User 2',
        date: DateTime.now(),
        createdAt: DateTime.now(),
        bookletId: 'main_cashbook', // Saved to 'main_cashbook'
      );

      final allTx = [txOldBooklet, txMainBooklet];

      // 1. Viewing 'old' booklet: strictly only sees 'old' transactions
      final oldMatching = allTx.where((tx) => tx.bookletId == 'old').toList();
      expect(oldMatching.length, 1);
      expect(oldMatching.first.id, 'tx_old1');

      // 2. Viewing 'main_cashbook': strictly only sees 'main_cashbook' transactions
      final mainMatching = allTx.where((tx) => tx.bookletId == 'main_cashbook').toList();
      expect(mainMatching.length, 1);
      expect(mainMatching.first.id, 'tx_main1');

      // 3. Newly created empty booklet: strictly sees 0 transactions (never leaks other booklets!)
      final emptyMatching = allTx.where((tx) => tx.bookletId == 'new_empty_booklet').toList();
      expect(emptyMatching.isEmpty, isTrue);
    });

    test('Bank passbook wallet deposit is incoming credit and isolated from split calculations', () {
      final walletTx = TransactionModel(
        id: 'tx_wallet_1',
        amount: 2000.0,
        category: 'wallet',
        paidByUid: 'user_1',
        paidByName: 'User 1',
        note: 'Wallet Deposit',
        type: TransactionType.received,
        date: DateTime(2026, 11, 5),
        createdAt: DateTime(2026, 11, 5),
        bookletId: 'bk_1',
      );

      final expenseTx = TransactionModel(
        id: 'tx_exp_1',
        amount: 500.0,
        category: 'Food',
        paidByUid: 'user_1',
        paidByName: 'User 1',
        type: TransactionType.paid,
        date: DateTime(2026, 11, 5),
        createdAt: DateTime(2026, 11, 5),
        bookletId: 'bk_1',
      );

      final transactions = [walletTx, expenseTx];

      // 1. Verify Passbook In/Out
      double totalReceived = 0;
      double totalPaid = 0;
      for (final tx in transactions) {
        if (tx.type == TransactionType.paid) {
          totalPaid += tx.amount;
        } else {
          totalReceived += tx.amount;
        }
      }

      expect(totalReceived, 2000.0);
      expect(totalPaid, 500.0);

      final walletReceived = transactions
          .where((t) => t.type == TransactionType.received && (t.category.toLowerCase() == 'wallet' || t.note?.toLowerCase() == 'wallet deposit'))
          .fold(0.0, (acc, t) => acc + t.amount);
      final nonWalletReceived = totalReceived - walletReceived;
      const displayedWalletAmount = 2000.0;

      final remainingBalance = displayedWalletAmount + nonWalletReceived - totalPaid;
      expect(remainingBalance, 1500.0);

      // 2. Verify group split calculation excludes wallet category
      final settlementTx = transactions.where((t) => t.category.toLowerCase() != 'wallet').toList();
      expect(settlementTx.length, 1);
      expect(settlementTx.first.id, 'tx_exp_1');

      final members = [(uid: 'user_1', name: 'User 1'), (uid: 'user_2', name: 'User 2')];
      final splitResult = calculateGroupSplit(transactions: settlementTx, members: members);
      expect(splitResult.totalExpense, 500.0);
      expect(splitResult.individualShare, 250.0);
    });
  });
}

