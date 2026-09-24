import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

// Import Service Locator (Injeksi Dependensi)

// Import Cubit
import 'features/transaction/presentation/cubit/transaction_cubit.dart';

// Import Pages
import 'features/transaction/presentation/pages/transaction_dashboard.dart';
import 'features/transaction/presentation/pages/transaction_form_page.dart';
import 'package:get_it/get_it.dart';
import '../../features/transaction/data/repositories/transaction_repository_impl.dart';
import '../../features/transaction/domain/repositories/transaction_repository.dart';
import '../../features/transaction/domain/usecases/transaction_usecases.dart';
final sl = GetIt.instance;

void initDI() {
  // 1. Cubit (Factory: Selalu buat instance baru saat halaman dibuka)
  sl.registerFactory<TransactionCubit>(() => TransactionCubit(
        getTransactions: sl(),
        addTransaction: sl(),
        updateTransaction: sl(),
        deleteTransaction: sl(),
      ));

  // 2. Use Cases (LazySingleton)
  sl.registerLazySingleton(() => GetTransactionsUseCase(sl()));
  sl.registerLazySingleton(() => AddTransactionUseCase(sl()));
  sl.registerLazySingleton(() => UpdateTransactionUseCase(sl()));
  sl.registerLazySingleton(() => DeleteTransactionUseCase(sl()));

  // 3. Repository (LazySingleton)
  sl.registerLazySingleton<TransactionRepository>(
      () => TransactionRepositoryImpl());
}
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Inisialisasi Dependency Injection GetIt (Modul 7)
  initDI(); 
  
  runApp(const MyMoneyApp());
}

class MyMoneyApp extends StatelessWidget {
  const MyMoneyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 2. Konfigurasi Navigasi Deklaratif GoRouter (Modul 4)
    final GoRouter router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const TransactionDashboard(),
        ),
        GoRoute(
          path: '/form',
          builder: (context, state) => const TransactionFormPage(),
        ),
      ],
    );

    // 3. Menyediakan Cubit ke seluruh pohon widget (Modul 6)
    return MultiBlocProvider(
      providers: [
        // Mengambil instance Cubit dari GetIt (sl = Service Locator)
        BlocProvider<TransactionCubit>(create: (_) => sl<TransactionCubit>()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'MyMoney',
        routerConfig: router,
        // 4. Konfigurasi Material 3 & Tema Gelap (Modul 5)
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
      ),
    );
  }
}