import '../entities/transaction_entity.dart';
import '../repositories/transaction_repository.dart';

class GetTransactionsUseCase {
  final TransactionRepository repository;
  GetTransactionsUseCase(this.repository);

  Future<List<TransactionEntity>> execute() => repository.getTransactions();
}

class AddTransactionUseCase {
  final TransactionRepository repository;
  AddTransactionUseCase(this.repository);

  Future<void> execute(TransactionEntity transaction) => repository.addTransaction(transaction);
}

class UpdateTransactionUseCase {
  final TransactionRepository repository;
  UpdateTransactionUseCase(this.repository);

  Future<void> execute(TransactionEntity transaction) => repository.updateTransaction(transaction);
}

class DeleteTransactionUseCase {
  final TransactionRepository repository;
  DeleteTransactionUseCase(this.repository);

  Future<void> execute(String id) => repository.deleteTransaction(id);
}