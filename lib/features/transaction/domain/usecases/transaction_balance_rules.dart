import '../entities/transaction_entity.dart';

class TransactionBalanceRules {
  static int effect(TransactionType type, int amount) {
    return type == TransactionType.income ? amount : -amount;
  }

  static int availableBalance({
    required int currentBalance,
    required String walletId,
    TransactionEntity? existingTransaction,
  }) {
    if (existingTransaction == null ||
        existingTransaction.walletId != walletId) {
      return currentBalance;
    }

    return currentBalance -
        effect(existingTransaction.type, existingTransaction.amount);
  }

  static String? validateAmount({
    required int amount,
    required TransactionType type,
    required int availableBalance,
  }) {
    if (amount <= 0) return 'Nominal harus lebih besar dari 0.';
    if (type == TransactionType.expense && amount > availableBalance) {
      return 'Saldo dompet tidak mencukupi. Saldo tersedia: Rp $availableBalance.';
    }
    return null;
  }
}
