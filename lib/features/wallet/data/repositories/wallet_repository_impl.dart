import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/wallet_entity.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../models/wallet_model.dart';

class WalletRepositoryImpl implements WalletRepository {
  WalletRepositoryImpl({required this._firestore, required this._auth});

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _userId {
    final user = _auth.currentUser;
    if (user == null || !user.emailVerified) {
      throw StateError(
        'A verified Firebase user is required to access wallets.',
      );
    }
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _wallets {
    return _firestore.collection('users').doc(_userId).collection('wallets');
  }

  @override
  Future<List<WalletEntity>> getWallets() async {
    final snapshot = await _wallets.orderBy('name').get();
    return snapshot.docs
        .map((doc) => WalletModel.fromJson({...doc.data(), 'id': doc.id}))
        .toList();
  }

  @override
  Future<void> addWallet(WalletEntity wallet) async {
    _validateWallet(wallet);
    await _wallets
        .doc(wallet.id)
        .set(
          WalletModel(
            id: wallet.id,
            name: wallet.name,
            balance: wallet.balance,
            iconName: wallet.iconName,
          ).toJson(),
        );
  }

  @override
  Future<void> updateWallet(WalletEntity wallet) {
    _validateWallet(wallet, allowBalanceChange: false);
    final walletRef = _wallets.doc(wallet.id);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(walletRef);
      final currentBalance = snapshot.data()?['balance'];
      if (!snapshot.exists || currentBalance is! int || currentBalance < 0) {
        throw StateError('Dompet tidak ditemukan atau saldonya tidak valid.');
      }
      transaction.update(walletRef, {
        'name': wallet.name.trim(),
        'iconName': wallet.iconName,
      });
    });
  }

  @override
  Future<void> deleteWallet(String id) async {
    final userId = _userId;
    final userCollection = _firestore.collection('users').doc(userId);
    final wallet = userCollection.collection('wallets').doc(id);
    final walletSnapshot = await wallet.get();
    if (!walletSnapshot.exists) {
      throw StateError('Dompet tidak ditemukan.');
    }
    final transactions = await userCollection
        .collection('transactions')
        .where('walletId', isEqualTo: id)
        .limit(1)
        .get();
    if (transactions.docs.isNotEmpty) {
      throw StateError(
        'Dompet ini masih digunakan oleh riwayat transaksi. Hapus atau pindahkan transaksinya terlebih dahulu.',
      );
    }
    await wallet.delete();
  }

  @override
  Future<bool> adjustBalance(String walletId, int delta) {
    final wallet = _wallets.doc(walletId);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(wallet);
      if (!snapshot.exists) return false;
      final balance = snapshot.data()?['balance'];
      if (balance is! int) {
        throw StateError('Wallet $walletId has an invalid balance.');
      }
      final updatedBalance = balance + delta;
      if (updatedBalance < 0) return false;
      transaction.update(wallet, {'balance': updatedBalance});
      return true;
    });
  }

  static void _validateWallet(
    WalletEntity wallet, {
    bool allowBalanceChange = true,
  }) {
    if (wallet.id.trim().isEmpty || wallet.name.trim().isEmpty) {
      throw ArgumentError('ID and name are required for a wallet.');
    }
    if (allowBalanceChange && wallet.balance < 0) {
      throw ArgumentError('A wallet balance cannot be negative.');
    }
  }
}
