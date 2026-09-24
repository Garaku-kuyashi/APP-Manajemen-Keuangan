import 'package:equatable/equatable.dart';
import '../../domain/entities/transaction_entity.dart';

sealed class TransactionState extends Equatable {
  const TransactionState();
  
  @override
  List<Object?> get props => [];
}

class DataInitial extends TransactionState {}

class DataLoading extends TransactionState {}

class DataSuccess extends TransactionState {
  final List<TransactionEntity> transactions;

  const DataSuccess({required this.transactions});

  @override
  List<Object?> get props => [transactions];
}

class DataError extends TransactionState {
  final String message;

  const DataError({required this.message});

  @override
  List<Object?> get props => [message];
}