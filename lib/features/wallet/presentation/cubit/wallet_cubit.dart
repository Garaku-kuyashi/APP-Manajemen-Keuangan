import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/wallet_entity.dart';
import '../../domain/usecases/wallet_usecases.dart';
import 'wallet_state.dart';

class WalletCubit extends Cubit<WalletState> {
  final GetWalletsUseCase getWallets;
  final AddWalletUseCase addWallet;
  final UpdateWalletUseCase updateWallet;
  final DeleteWalletUseCase deleteWallet;

  WalletCubit({
    required this.getWallets,
    required this.addWallet,
    required this.updateWallet,
    required this.deleteWallet,
  }) : super(WalletInitial());

  Future<void> loadWallets() async {
    emit(WalletLoading());
    try {
      final data = await getWallets.execute();
      emit(WalletSuccess(wallets: data));
    } catch (e) {
      emit(WalletError(message: e.toString()));
    }
  }

  /// Menambah dompet BARU.
  Future<void> add(WalletEntity wallet) async {
    emit(WalletLoading());
    try {
      await addWallet.execute(wallet);
      await loadWallets();
    } catch (e) {
      emit(WalletError(message: e.toString()));
    }
  }

  Future<void> update(WalletEntity wallet) async {
    emit(WalletLoading());
    try {
      await updateWallet.execute(wallet);
      await loadWallets();
    } catch (e) {
      emit(WalletError(message: e.toString()));
    }
  }

  Future<void> delete(String id) async {
    emit(WalletLoading());
    try {
      await deleteWallet.execute(id);
      await loadWallets();
    } catch (e) {
      emit(WalletError(message: e.toString()));
    }
  }
}