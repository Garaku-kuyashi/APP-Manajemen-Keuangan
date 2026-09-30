import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../models/transaction_model.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  final List<TransactionModel> _mockDatabase = [
    TransactionModel(
      id: '1',
      title: 'Uang Saku Bulanan',
      amount: 2500000,
      date: DateTime.now().subtract(const Duration(days: 5)),
      category: 'Uang Saku',
      type: TransactionType.income,
      walletId: 'w2',
      walletName: 'Rekening Utama (BCA)',
    ),
    TransactionModel(
      id: '2',
      title: 'ChatGPT & Midjourney AI',
      amount: 320000,
      date: DateTime.now().subtract(const Duration(days: 2)),
      category: 'Langganan AI',
      type: TransactionType.expense,
      walletId: 'w1',
      walletName: 'Gopay / OVO',
    ),
    TransactionModel(
      id: '3',
      title: 'Spotify & Netflix Student',
      amount: 85000,
      date: DateTime.now().subtract(const Duration(days: 1)),
      category: 'Hiburan & Streaming',
      type: TransactionType.expense,
      walletId: 'w1',
      walletName: 'Gopay / OVO',
    ),
  ];

  @override
  Future<List<TransactionEntity>> getTransactions() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.from(_mockDatabase);
  }

  @override
  Future<void> addTransaction(TransactionEntity transaction) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final model = TransactionModel(
      id: transaction.id,
      title: transaction.title,
      amount: transaction.amount,
      date: transaction.date,
      category: transaction.category,
      type: transaction.type,
      walletId: transaction.walletId,
      walletName: transaction.walletName,
    );
    _mockDatabase.insert(0, model);
  }

  @override
  Future<void> updateTransaction(TransactionEntity transaction) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _mockDatabase.indexWhere((element) => element.id == transaction.id);
    if (index != -1) {
      _mockDatabase[index] = TransactionModel(
        id: transaction.id,
        title: transaction.title,
        amount: transaction.amount,
        date: transaction.date,
        category: transaction.category,
        type: transaction.type,
        walletId: transaction.walletId,
        walletName: transaction.walletName,
      );
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mockDatabase.removeWhere((element) => element.id == id);
  }
}