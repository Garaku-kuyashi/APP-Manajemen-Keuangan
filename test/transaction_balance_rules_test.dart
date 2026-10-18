import 'package:flutter_test/flutter_test.dart';
import 'package:mymoney/features/transaction/domain/entities/transaction_entity.dart';
import 'package:mymoney/features/transaction/domain/usecases/transaction_balance_rules.dart';
import 'package:mymoney/features/wallet/domain/entities/wallet_entity.dart';
import 'package:mymoney/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:mymoney/features/wallet/domain/usecases/wallet_usecases.dart';
import 'package:mymoney/features/wallet/presentation/cubit/wallet_cubit.dart';
import 'package:mymoney/features/wallet/presentation/cubit/wallet_state.dart';

void main() {
  group('TransactionBalanceRules.validateAmount', () {
    test('accepts an expense within the available balance', () {
      expect(
        TransactionBalanceRules.validateAmount(
          amount: 70000,
          type: TransactionType.expense,
          availableBalance: 100000,
        ),
        isNull,
      );
    });

    test('accepts an expense equal to the available balance', () {
      expect(
        TransactionBalanceRules.validateAmount(
          amount: 100000,
          type: TransactionType.expense,
          availableBalance: 100000,
        ),
        isNull,
      );
    });

    test('rejects an expense above the available balance', () {
      expect(
        TransactionBalanceRules.validateAmount(
          amount: 100001,
          type: TransactionType.expense,
          availableBalance: 100000,
        ),
        contains('Saldo dompet tidak mencukupi'),
      );
    });

    test('rejects zero and negative amounts', () {
      for (final amount in [0, -1]) {
        expect(
          TransactionBalanceRules.validateAmount(
            amount: amount,
            type: TransactionType.income,
            availableBalance: 100000,
          ),
          'Nominal harus lebih besar dari 0.',
        );
      }
    });

    test('does not cap income at the current balance', () {
      expect(
        TransactionBalanceRules.validateAmount(
          amount: 500000,
          type: TransactionType.income,
          availableBalance: 100000,
        ),
        isNull,
      );
    });
  });

  group('TransactionBalanceRules.availableBalance', () {
    final existingExpense = TransactionEntity(
      id: 'expense',
      title: 'Old expense',
      amount: 40000,
      date: DateTime(2026),
      category: 'Other',
      type: TransactionType.expense,
      walletId: 'wallet-1',
      walletName: 'Cash',
    );

    test('restores the old expense amount when editing in the same wallet', () {
      expect(
        TransactionBalanceRules.availableBalance(
          currentBalance: 60000,
          walletId: 'wallet-1',
          existingTransaction: existingExpense,
        ),
        100000,
      );
    });

    test('does not restore an old transaction from another wallet', () {
      expect(
        TransactionBalanceRules.availableBalance(
          currentBalance: 20000,
          walletId: 'wallet-2',
          existingTransaction: existingExpense,
        ),
        20000,
      );
    });

    test('reverses an old income when editing it into an expense', () {
      final existingIncome = TransactionEntity(
        id: 'income',
        title: 'Old income',
        amount: 50000,
        date: DateTime(2026),
        category: 'Other',
        type: TransactionType.income,
        walletId: 'wallet-1',
        walletName: 'Cash',
      );

      expect(
        TransactionBalanceRules.availableBalance(
          currentBalance: 150000,
          walletId: 'wallet-1',
          existingTransaction: existingIncome,
        ),
        100000,
      );
    });
  });

  group('WalletCubit.adjustBalance', () {
    late _InMemoryWalletRepository repository;
    late WalletCubit cubit;

    setUp(() {
      repository = _InMemoryWalletRepository([
        const WalletEntity(
          id: 'wallet-1',
          name: 'Cash',
          balance: 100,
          iconName: 'payments',
        ),
      ]);
      cubit = WalletCubit(
        getWallets: GetWalletsUseCase(repository),
        addWallet: AddWalletUseCase(repository),
        updateWallet: UpdateWalletUseCase(repository),
        deleteWallet: DeleteWalletUseCase(repository),
      );
    });

    tearDown(() => cubit.close());

    test('refuses a balance adjustment that would go below zero', () async {
      await cubit.loadWallets();
      expect(await cubit.adjustBalance('wallet-1', -101), isFalse);
      expect(repository.wallets.single.balance, 100);
      expect(cubit.state, isA<WalletSuccess>());
    });

    test('allows spending the exact wallet balance', () async {
      expect(await cubit.adjustBalance('wallet-1', -100), isTrue);
      expect(repository.wallets.single.balance, 0);
    });

    test('returns false when the wallet does not exist', () async {
      await cubit.loadWallets();
      expect(await cubit.adjustBalance('missing-wallet', -1), isFalse);
      expect(repository.wallets.single.balance, 100);
      expect(cubit.state, isA<WalletSuccess>());
    });
  });
}

class _InMemoryWalletRepository implements WalletRepository {
  _InMemoryWalletRepository(this.wallets);

  final List<WalletEntity> wallets;

  @override
  Future<List<WalletEntity>> getWallets() async => List.of(wallets);

  @override
  Future<void> addWallet(WalletEntity wallet) async => wallets.add(wallet);

  @override
  Future<void> updateWallet(WalletEntity wallet) async {
    final index = wallets.indexWhere((item) => item.id == wallet.id);
    if (index != -1) wallets[index] = wallet;
  }

  @override
  Future<void> deleteWallet(String id) async {
    wallets.removeWhere((wallet) => wallet.id == id);
  }
}
