import '../../domain/entities/wallet_entity.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../models/wallet_model.dart';

class WalletRepositoryImpl implements WalletRepository {
  // Seed data awal dompet khas mahasiswa
  final List<WalletModel> _mockWallets = [
    const WalletModel(
      id: 'w1',
      name: 'Gopay / OVO',
      balance: 150000,
      iconName: 'account_balance_wallet',
    ),
    const WalletModel(
      id: 'w2',
      name: 'Rekening Utama (BCA)',
      balance: 2000000,
      iconName: 'account_balance',
    ),
    const WalletModel(
      id: 'w3',
      name: 'Dompet Tunai (Cash)',
      balance: 350000,
      iconName: 'payments',
    ),
  ];

  @override
  Future<List<WalletEntity>> getWallets() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.from(_mockWallets);
  }

  @override
  Future<void> addWallet(WalletEntity wallet) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final model = WalletModel(
      id: wallet.id,
      name: wallet.name,
      balance: wallet.balance,
      iconName: wallet.iconName,
    );
    _mockWallets.add(model);
  }

  @override
  Future<void> updateWallet(WalletEntity wallet) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _mockWallets.indexWhere((e) => e.id == wallet.id);
    if (index != -1) {
      _mockWallets[index] = WalletModel(
        id: wallet.id,
        name: wallet.name,
        balance: wallet.balance,
        iconName: wallet.iconName,
      );
    }
  }

  @override
  Future<void> deleteWallet(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _mockWallets.removeWhere((e) => e.id == id);
  }
}