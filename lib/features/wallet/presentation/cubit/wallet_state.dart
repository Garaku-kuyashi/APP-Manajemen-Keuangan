import 'package:equatable/equatable.dart';
import '../../domain/entities/wallet_entity.dart';

sealed class WalletState extends Equatable {
  const WalletState();

  @override
  List<Object?> get props => [];
}

class WalletInitial extends WalletState {}

class WalletLoading extends WalletState {}

class WalletSuccess extends WalletState {
  final List<WalletEntity> wallets;

  const WalletSuccess({required this.wallets});

  @override
  List<Object?> get props => [wallets];
}

class WalletError extends WalletState {
  final String message;

  const WalletError({required this.message});

  @override
  List<Object?> get props => [message];
}