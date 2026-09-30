import 'package:equatable/equatable.dart';

class WalletEntity extends Equatable {
  final String id;
  final String name;      // Misal: Gopay, Bank BCA, Cash
  final int balance;      // Saldo di dompet ini
  final String iconName;  // Misal: 'wallet', 'credit_card', 'account_balance'

  const WalletEntity({
    required this.id,
    required this.name,
    required this.balance,
    required this.iconName,
  });

  @override
  List<Object?> get props => [id, name, balance, iconName];
}