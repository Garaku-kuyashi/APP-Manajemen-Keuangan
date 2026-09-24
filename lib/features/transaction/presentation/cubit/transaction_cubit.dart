import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/usecases/transaction_usecases.dart';
import 'transaction_state.dart';

class TransactionCubit extends Cubit<TransactionState> {
  final GetTransactionsUseCase getTransactions;
  final AddTransactionUseCase addTransaction;
  final UpdateTransactionUseCase updateTransaction;
  final DeleteTransactionUseCase deleteTransaction;

  TransactionCubit({
    required this.getTransactions,
    required this.addTransaction,
    required this.updateTransaction,
    required this.deleteTransaction,
  }) : super(DataInitial());

  Future<void> loadTransactions() async {
    emit(DataLoading());
    try {
      final data = await getTransactions.execute();
      emit(DataSuccess(transactions: data));
    } catch (e) {
      emit(DataError(message: e.toString()));
    }
  }

  Future<void> add(TransactionEntity transaction) async {
    emit(DataLoading());
    try {
      await addTransaction.execute(transaction);
      await loadTransactions();
    } catch (e) {
      emit(DataError(message: e.toString()));
    }
  }

  Future<void> delete(String id) async {
    emit(DataLoading());
    try {
      await deleteTransaction.execute(id);
      await loadTransactions();
    } catch (e) {
      emit(DataError(message: e.toString()));
    }
  }
}