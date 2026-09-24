import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../models/transaction_model.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  // Simulasi Data Source In-Memory
  final List<TransactionModel> _mockDatabase = [];

  @override
  Future<List<TransactionEntity>> getTransactions() async {
    try {
      await Future.delayed(const Duration(seconds: 1)); // Simulasi latensi jaringan
      return List<TransactionEntity>.from(_mockDatabase);
    } catch (e) {
      throw Exception('Gagal memuat transaksi: $e');
    }
  }

  @override
  Future<void> addTransaction(TransactionEntity transaction) async {
    try {
      await Future.delayed(const Duration(seconds: 1));
      final model = TransactionModel.fromEntity(transaction);
      _mockDatabase.add(model);
    } catch (e) {
      throw Exception('Gagal menambah transaksi: $e');
    }
  }

  @override
  Future<void> updateTransaction(TransactionEntity transaction) async {
    try {
      await Future.delayed(const Duration(seconds: 1));
      final index = _mockDatabase.indexWhere((t) => t.id == transaction.id);
      if (index != -1) {
        _mockDatabase[index] = TransactionModel.fromEntity(transaction);
      } else {
        throw Exception('Transaksi tidak ditemukan');
      }
    } catch (e) {
      throw Exception('Gagal memperbarui transaksi: $e');
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    try {
      await Future.delayed(const Duration(seconds: 1));
      _mockDatabase.removeWhere((t) => t.id == id);
    } catch (e) {
      throw Exception('Gagal menghapus transaksi: $e');
    }
  }
}