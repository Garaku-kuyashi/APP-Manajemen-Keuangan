import '../entities/wallet_entity.dart';

abstract class WalletRepository {
  Future<List<WalletEntity>> getWallets();
  Future<void> addWallet(WalletEntity wallet);
  Future<void> updateWallet(WalletEntity wallet);
  Future<void> deleteWallet(String id);
}