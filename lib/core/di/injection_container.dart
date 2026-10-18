import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import '../../features/chat/data/chat_repository.dart';
import '../../features/transaction/data/repositories/transaction_repository_impl.dart';
import '../../features/transaction/domain/repositories/transaction_repository.dart';
import '../../features/transaction/domain/usecases/transaction_usecases.dart';
import '../../features/transaction/presentation/cubit/transaction_cubit.dart';

// Import Fitur Wallet
import '../../features/wallet/data/repositories/wallet_repository_impl.dart';
import '../../features/wallet/domain/repositories/wallet_repository.dart';
import '../../features/wallet/domain/usecases/wallet_usecases.dart';
import '../../features/wallet/presentation/cubit/wallet_cubit.dart';

final sl = GetIt.instance;

void initDI({
  required FirebaseFirestore firestore,
  required FirebaseAuth auth,
}) {
  // === TRANSACTION FEATURE ===
  sl.registerFactory<TransactionCubit>(() => TransactionCubit(
        getTransactions: sl(),
        addTransaction: sl(),
        updateTransaction: sl(),
        deleteTransaction: sl(),
      ));
  sl.registerLazySingleton(() => GetTransactionsUseCase(sl()));
  sl.registerLazySingleton(() => AddTransactionUseCase(sl()));
  sl.registerLazySingleton(() => UpdateTransactionUseCase(sl()));
  sl.registerLazySingleton(() => DeleteTransactionUseCase(sl()));
  sl.registerLazySingleton<TransactionRepository>(
    () => TransactionRepositoryImpl(firestore: firestore, auth: auth),
  );
  sl.registerLazySingleton<ChatRepository>(
    () => ChatRepository(firestore: firestore, auth: auth),
  );

  // === WALLET FEATURE (BARU) ===
  sl.registerFactory<WalletCubit>(() => WalletCubit(
        updateWallet: sl(),
        getWallets: sl(),
        addWallet: sl(),
        deleteWallet: sl(),
        adjustWalletBalance: sl(),
      ));
  sl.registerLazySingleton(() => GetWalletsUseCase(sl()));
  sl.registerLazySingleton(() => AddWalletUseCase(sl()));
  sl.registerLazySingleton(() => DeleteWalletUseCase(sl()));
  sl.registerLazySingleton(() => AdjustWalletBalanceUseCase(sl()));
  sl.registerLazySingleton(() => UpdateWalletUseCase(sl()));
  sl.registerLazySingleton<WalletRepository>(
    () => WalletRepositoryImpl(firestore: firestore, auth: auth),
  );
}