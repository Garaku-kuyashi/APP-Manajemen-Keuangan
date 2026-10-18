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
      final transactions = await getTransactions.execute();
      emit(DataSuccess(transactions: transactions));
    } catch (e) {
      emit(DataError(message: e.toString()));
    }
  }

  Future<bool> add(TransactionEntity transaction) async {
    emit(DataLoading());
    try {
      await addTransaction.execute(transaction);
      await loadTransactions();
      return state is DataSuccess;
    } catch (e) {
      emit(DataError(message: e.toString()));
      return false;
    }
  }

  // METHOD EDIT / UPDATE TRANSAKSI
  Future<bool> update(TransactionEntity transaction) async {
    emit(DataLoading());
    try {
      await updateTransaction.execute(transaction);
      await loadTransactions();
      return state is DataSuccess;
    } catch (e) {
      emit(DataError(message: e.toString()));
      return false;
    }
  }

  Future<bool> delete(String id) async {
    emit(DataLoading());
    try {
      await deleteTransaction.execute(id);
      await loadTransactions();
      return state is DataSuccess;
    } catch (e) {
      emit(DataError(message: e.toString()));
      return false;
    }
  }
}