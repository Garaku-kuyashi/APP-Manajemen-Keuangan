import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/transaction_entity.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../models/transaction_model.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl({required this._firestore, required this._auth});

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _transactions =>
      _userCollection('transactions');

  CollectionReference<Map<String, dynamic>> _userCollection(String name) {
    final user = _auth.currentUser;
    if (user == null || !user.emailVerified) {
      throw StateError(
        'A verified Firebase user is required to access transactions.',
      );
    }
    return _firestore.collection('users').doc(user.uid).collection(name);
  }

  @override
  Future<List<TransactionEntity>> getTransactions() async {
    final snapshot = await _transactions
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => TransactionModel.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  @override
  Future<void> addTransaction(TransactionEntity transaction) {
    _validateTransaction(transaction);
    final transactionRef = _transactions.doc(transaction.id);
    final walletRef = _userCollection('wallets').doc(transaction.walletId);

    return _firestore.runTransaction((firestoreTransaction) async {
      final transactionSnapshot = await firestoreTransaction.get(
        transactionRef,
      );
      if (transactionSnapshot.exists) {
        throw StateError('A transaction with this ID already exists.');
      }
      final walletSnapshot = await firestoreTransaction.get(walletRef);
      final walletData = walletSnapshot.data();
      if (!walletSnapshot.exists || walletData == null) {
        throw StateError('The selected wallet no longer exists.');
      }

      final balance = walletData['balance'];
      if (balance is! int) throw StateError('The wallet balance is invalid.');
      final updatedBalance = balance + _effect(transaction);
      if (updatedBalance < 0) {
        throw StateError('The selected wallet does not have enough balance.');
      }

      firestoreTransaction.update(walletRef, {'balance': updatedBalance});
      firestoreTransaction.set(
        transactionRef,
        TransactionModel(
          id: transaction.id,
          title: transaction.title,
          amount: transaction.amount,
          date: transaction.date,
          category: transaction.category,
          type: transaction.type,
          walletId: transaction.walletId,
          walletName: transaction.walletName,
        ).toJson(),
      );
    });
  }

  @override
  Future<void> updateTransaction(TransactionEntity transaction) {
    _validateTransaction(transaction);
    final transactionRef = _transactions.doc(transaction.id);
    final walletCollection = _userCollection('wallets');
    final newWalletRef = walletCollection.doc(transaction.walletId);

    return _firestore.runTransaction((firestoreTransaction) async {
      final oldTransactionSnapshot = await firestoreTransaction.get(
        transactionRef,
      );
      final oldData = oldTransactionSnapshot.data();
      if (!oldTransactionSnapshot.exists || oldData == null) {
        throw StateError('The transaction no longer exists.');
      }
      final oldTransaction = TransactionModel.fromJson({
        ...oldData,
        'id': transaction.id,
      });
      final oldWalletRef = walletCollection.doc(oldTransaction.walletId);
      final oldWalletSnapshot = await firestoreTransaction.get(oldWalletRef);
      final newWalletSnapshot = oldTransaction.walletId == transaction.walletId
          ? oldWalletSnapshot
          : await firestoreTransaction.get(newWalletRef);
      final oldWalletData = oldWalletSnapshot.data();
      final newWalletData = newWalletSnapshot.data();

      if (!oldWalletSnapshot.exists || oldWalletData == null) {
        throw StateError('The original wallet no longer exists.');
      }
      if (!newWalletSnapshot.exists || newWalletData == null) {
        throw StateError('The selected wallet no longer exists.');
      }
      final oldBalance = oldWalletData['balance'];
      final newBalance = newWalletData['balance'];
      if (oldBalance is! int || newBalance is! int) {
        throw StateError('A wallet balance is invalid.');
      }

      final restoredOldBalance = oldBalance - _effect(oldTransaction);
      final updatedNewBalance = oldTransaction.walletId == transaction.walletId
          ? restoredOldBalance + _effect(transaction)
          : newBalance + _effect(transaction);
      if (restoredOldBalance < 0 || updatedNewBalance < 0) {
        throw StateError('The selected wallet does not have enough balance.');
      }

      if (oldTransaction.walletId == transaction.walletId) {
        firestoreTransaction.update(oldWalletRef, {
          'balance': updatedNewBalance,
        });
      } else {
        firestoreTransaction.update(oldWalletRef, {
          'balance': restoredOldBalance,
        });
        firestoreTransaction.update(newWalletRef, {
          'balance': updatedNewBalance,
        });
      }
      firestoreTransaction.set(
        transactionRef,
        TransactionModel(
          id: transaction.id,
          title: transaction.title,
          amount: transaction.amount,
          date: transaction.date,
          category: transaction.category,
          type: transaction.type,
          walletId: transaction.walletId,
          walletName: transaction.walletName,
        ).toJson(),
      );
    });
  }

  @override
  Future<void> deleteTransaction(String id) {
    final transactionRef = _transactions.doc(id);
    final walletCollection = _userCollection('wallets');

    return _firestore.runTransaction((firestoreTransaction) async {
      final transactionSnapshot = await firestoreTransaction.get(
        transactionRef,
      );
      final data = transactionSnapshot.data();
      if (!transactionSnapshot.exists || data == null) {
        throw StateError('The transaction no longer exists.');
      }
      final transaction = TransactionModel.fromJson({...data, 'id': id});
      final walletRef = walletCollection.doc(transaction.walletId);
      final walletSnapshot = await firestoreTransaction.get(walletRef);
      final walletData = walletSnapshot.data();
      if (!walletSnapshot.exists || walletData == null) {
        throw StateError('The transaction wallet no longer exists.');
      }
      final balance = walletData['balance'];
      if (balance is! int) throw StateError('The wallet balance is invalid.');

      final restoredBalance = balance - _effect(transaction);
      if (restoredBalance < 0) {
        throw StateError(
          'Dompet tidak dapat dipulihkan tanpa membuat saldonya negatif.',
        );
      }
      firestoreTransaction.update(walletRef, {'balance': restoredBalance});
      firestoreTransaction.delete(transactionRef);
    });
  }

  static int _effect(TransactionEntity transaction) =>
      transaction.type == TransactionType.income
      ? transaction.amount
      : -transaction.amount;

  static void _validateTransaction(TransactionEntity transaction) {
    if (transaction.id.trim().isEmpty ||
        transaction.title.trim().isEmpty ||
        transaction.amount <= 0 ||
        transaction.walletId.trim().isEmpty) {
      throw ArgumentError(
        'A transaction requires an ID, title, positive amount, and wallet.',
      );
    }
  }
}
