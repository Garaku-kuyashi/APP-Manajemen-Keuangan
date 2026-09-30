import '../entities/wallet_entity.dart';
import '../repositories/wallet_repository.dart';

class GetWalletsUseCase {
  final WalletRepository repository;
  GetWalletsUseCase(this.repository);
  Future<List<WalletEntity>> execute() => repository.getWallets();
}

class AddWalletUseCase {
  final WalletRepository repository;
  AddWalletUseCase(this.repository);
  Future<void> execute(WalletEntity wallet) => repository.addWallet(wallet);
}

class DeleteWalletUseCase {
  final WalletRepository repository;
  DeleteWalletUseCase(this.repository);
  Future<void> execute(String id) => repository.deleteWallet(id);
}