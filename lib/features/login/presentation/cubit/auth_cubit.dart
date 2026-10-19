import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Presentation hanya mengatur state dan delegasi pekerjaan autentikasi
/// ke AuthRepository. Tidak bergantung langsung pada FirebaseAuth.
class AuthCubit extends Cubit<AuthUser?> with WidgetsBindingObserver {
  final AuthRepository _authRepository;
  final ValueNotifier<int> _tick = ValueNotifier(0);
  late final StreamSubscription<AuthUser?> _authSubscription;
  late final Timer _accountCheckTimer;
  bool _checkingRemoteAccount = false;
  bool _receivedInitialAuthState = false;

  AuthCubit(this._authRepository) : super(_authRepository.currentUser) {
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = _authRepository.authStateChanges.listen(
      _onAuthStateChanged,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Auth state stream failed: $error');
      },
    );
    _accountCheckTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => unawaited(_validateRemoteAccount()),
    );
  }

  bool get isLoggedIn => state != null;

  /// Digunakan oleh GoRouter.refreshListenable.
  Listenable get listenable => _tick;

  String? redirect(BuildContext context, GoRouterState routeState) {
    final path = routeState.matchedLocation;
    final onAuthPage = path == '/login' || path == '/register';

    if (!isLoggedIn) return onAuthPage ? null : '/login';
    if (path == '/verify-email' && state?.emailVerified == true) return '/';
    if (state?.emailVerified != true) {
      return path == '/verify-email' ? null : '/verify-email';
    }
    return onAuthPage ? '/' : null;
  }

  Future<String?> register(String name, String email, String password) async {
    final error = await _authRepository.register(
      name: name,
      email: email,
      password: password,
    );
    if (error == null) _set(_authRepository.currentUser);
    return error;
  }

  Future<String?> login(String email, String password) async {
    final error = await _authRepository.login(email: email, password: password);
    if (error == null) _set(_authRepository.currentUser);
    return error;
  }

  Future<String?> logout() async {
    final error = await _authRepository.logout();
    if (error == null) _set(null);
    return error;
  }

  Future<String?> resendVerificationEmail() async {
    return _authRepository.resendVerificationEmail();
  }

  Future<String?> refreshEmailVerification() async {
    final error = await _authRepository.refreshEmailVerification();
    _set(_authRepository.currentUser);
    return error;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      unawaited(_validateRemoteAccount());
    }
  }

  Future<void> _validateRemoteAccount({
    bool refreshVerifiedToken = false,
  }) async {
    if (_authRepository.currentUser == null ||
        _checkingRemoteAccount ||
        isClosed) {
      return;
    }

    _checkingRemoteAccount = true;
    try {
      final user = await _authRepository.validateRemoteAccount(
        refreshVerifiedToken: refreshVerifiedToken,
      );
      if (!isClosed) _set(user);
    } catch (error) {
      debugPrint('Validasi akun gagal: $error');
    } finally {
      _checkingRemoteAccount = false;
    }
  }

  void _onAuthStateChanged(AuthUser? user) {
    _set(user);
    if (!_receivedInitialAuthState) {
      _receivedInitialAuthState = true;
      if (user != null) {
        unawaited(_validateRemoteAccount(refreshVerifiedToken: true));
      }
    }
  }

  void _set(AuthUser? user) {
    if (isClosed) return;
    emit(user);
    _tick.value++;
  }

  @override
  Future<void> close() async {
    WidgetsBinding.instance.removeObserver(this);
    _accountCheckTimer.cancel();
    await _authSubscription.cancel();
    _tick.dispose();
    await super.close();
  }

  Future<String?> updateDisplayName(String name) async {
    final error = await _authRepository.updateDisplayName(name);

    if (error == null) {
      await _authRepository.validateRemoteAccount();
      _set(_authRepository.currentUser);
    }

    return error;
  }

  AuthUser? get currentUser => _authRepository.currentUser;
}
