import 'package:equatable/equatable.dart';

enum TransactionType { income, expense }

class TransactionEntity extends Equatable {
  final String id;
  final String title;
  final int amount;
  final DateTime date;
  final String category;
  final TransactionType type;
  final String walletId;   // ID Dompet terhubung
  final String walletName; // Nama Dompet terhubung (Gopay/BCA/Cash)

  const TransactionEntity({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    required this.type,
    required this.walletId,
    required this.walletName,
  });

  @override
  List<Object?> get props => [id, title, amount, date, category, type, walletId, walletName];
}