import '../../domain/entities/transaction_entity.dart';

class TransactionModel extends TransactionEntity {
  const TransactionModel({
    required super.id,
    required super.title,
    required super.amount,
    required super.date,
    required super.category,
    required super.type,
    required super.walletId,
    required super.walletName,
  });

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'],
      title: json['title'],
      amount: json['amount'],
      date: DateTime.parse(json['date']),
      category: json['category'] ?? 'Lainnya',
      type: json['type'] == 'income' ? TransactionType.income : TransactionType.expense,
      walletId: json['walletId'] ?? 'w1',
      walletName: json['walletName'] ?? 'Gopay / OVO',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'type': type == TransactionType.income ? 'income' : 'expense',
      'walletId': walletId,
      'walletName': walletName,
    };
  }
}