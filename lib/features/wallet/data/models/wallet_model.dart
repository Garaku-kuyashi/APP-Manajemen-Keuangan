import '../../domain/entities/wallet_entity.dart';

class WalletModel extends WalletEntity {
  const WalletModel({
    required super.id,
    required super.name,
    required super.balance,
    required super.iconName,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      balance: json['balance'] as int? ?? 0,
      iconName: json['iconName'] as String? ?? 'account_balance_wallet',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'balance': balance,
      'iconName': iconName,
    };
  }
}