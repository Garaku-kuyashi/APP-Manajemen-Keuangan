import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:mymoney/features/login/presentation/cubit/auth_cubit.dart';
import 'package:mymoney/features/login/domain/repositories/auth_repository.dart';
import 'package:mymoney/features/login/presentation/auth_routes.dart';

import 'core/di/injection_container.dart';
import 'core/di/theme/theme_cubit.dart';
import 'features/chat/data/chat_repository.dart';
import 'firebase_options.dart';
import 'features/transaction/presentation/cubit/transaction_cubit.dart';
import 'features/transaction/presentation/pages/transaction_dashboard.dart';
import 'features/transaction/presentation/pages/transaction_form_page.dart';
import 'features/wallet/presentation/cubit/wallet_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  initDI(
    firestore: FirebaseFirestore.instance,
    auth: FirebaseAuth.instance,
  );

  final authCubit = AuthCubit(sl<AuthRepository>());

  runApp(MyMoneyApp(authCubit: authCubit));
}

class MyMoneyApp extends StatelessWidget {
  final AuthCubit authCubit;

  const MyMoneyApp({super.key, required this.authCubit});

  @override
  Widget build(BuildContext context) {
    final GoRouter router = GoRouter(
      initialLocation: '/',
      refreshListenable: authCubit.listenable,
      redirect: authCubit.redirect,
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const TransactionDashboard(),
        ),
        GoRoute(
          path: '/form',
          builder: (context, state) => const TransactionFormPage(),
        ),
        ...authRoutes,
      ],
    );

    return MultiBlocProvider(
      providers: [
        RepositoryProvider<ChatRepository>(create: (_) => sl<ChatRepository>()),
        BlocProvider<AuthCubit>.value(value: authCubit),
        BlocProvider<TransactionCubit>(create: (_) => sl<TransactionCubit>()),
        BlocProvider<WalletCubit>(create: (_) => sl<WalletCubit>()),
        BlocProvider<ThemeCubit>(create: (_) => ThemeCubit()), // Tambahkan ThemeCubit
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            title: 'MyMoney',
            routerConfig: router,
            themeMode: themeMode, // Tema Reaktif
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: Colors.blueGrey,
              brightness: Brightness.light, // Preset Mode Terang
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: Colors.blueGrey,
              brightness: Brightness.dark, // Preset Mode Gelap
            ),
          );
        },
      ),
    );
  }
}
