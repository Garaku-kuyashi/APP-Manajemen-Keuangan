import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';

import 'core/di/injection_container.dart';
import 'core/di/theme/theme_cubit.dart';
import 'features/login/login_feature.dart';
import 'firebase_options.dart';
import 'features/transaction/presentation/cubit/transaction_cubit.dart';
import 'features/transaction/presentation/pages/transaction_dashboard.dart';
import 'features/transaction/presentation/pages/transaction_form_page.dart';
import 'features/wallet/presentation/cubit/wallet_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  initDI();
  final authCubit = AuthCubit(FirebaseAuth.instance);
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
        ...authRoutes, // /login dan /register
      ],
    );

    return MultiBlocProvider(
      providers: [
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
