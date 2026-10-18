import 'package:cloud_firestore/cloud_firestore.dart';

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
    final rawDate = json['date'];
    final date = switch (rawDate) {
      Timestamp value => value.toDate(),
      DateTime value => value,
      String value => DateTime.parse(value),
      _ => throw FormatException('Invalid transaction date: $rawDate'),
    };
    return TransactionModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      amount: json['amount'] as int? ?? 0,
      date: date,
      category: json['category'] as String? ?? 'Lainnya',
      type: json['type'] == 'income' ? TransactionType.income : TransactionType.expense,
      walletId: json['walletId'] as String? ?? '',
      walletName: json['walletName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'category': category,
      'type': type == TransactionType.income ? 'income' : 'expense',
      'walletId': walletId,
      'walletName': walletName,
    };
  }
}