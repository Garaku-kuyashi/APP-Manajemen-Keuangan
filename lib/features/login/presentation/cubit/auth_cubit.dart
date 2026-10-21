import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/monthly_budget_service.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Presentation mengatur state dan mendelegasikan autentikasi ke repository.
class AuthCubit extends Cubit<AuthUser?> with WidgetsBindingObserver {
  final AuthRepository _authRepository;
  final MonthlyBudgetService _monthlyBudgetService;
  final ValueNotifier<int> _tick = ValueNotifier(0);
  late final StreamSubscription<AuthUser?> _authSubscription;
  late final Timer _accountCheckTimer;
  StreamSubscription<int>? _budgetSubscription;
  String? _budgetUserId;
  bool _checkingRemoteAccount = false;
  bool _receivedInitialAuthState = false;

  AuthCubit(this._authRepository, {MonthlyBudgetService? monthlyBudgetService})
    : _monthlyBudgetService = monthlyBudgetService ?? MonthlyBudgetService(),
      super(_authRepository.currentUser) {
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

    final userId = state?.uid;
    if (userId != null) {
      unawaited(_loadProfilePhoto(userId));
      unawaited(_initializeMonthlyBudget(userId));
    }
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

    final current = state;
    final sameUser = current != null && current.uid == user?.uid;
    final nextUser = current != null && user != null && current.uid == user.uid
        ? user.copyWith(
            profilePhotoBytes: current.profilePhotoBytes,
            monthlyBudget: current.monthlyBudget,
          )
        : user;

    // GoRouter hanya perlu di-refresh jika berubahnya status login atau
    // verifikasi email memengaruhi redirect. Perubahan nama, foto, dan budget
    // cukup memperbarui state Cubit; jangan memicu refresh router saat dialog
    // profil sedang terbuka karena dapat mengganggu siklus hidup route/overlay.
    final routeStateChanged =
        current?.uid != nextUser?.uid ||
        current?.emailVerified != nextUser?.emailVerified;

    emit(nextUser);
    if (routeStateChanged) _tick.value++;

    if (user == null) {
      _cancelMonthlyBudgetWatch();
      return;
    }

    if (!sameUser) {
      unawaited(_loadProfilePhoto(user.uid));
    }
    if (_budgetUserId != user.uid) {
      unawaited(_initializeMonthlyBudget(user.uid));
    }
  }

  Future<void> _loadProfilePhoto(String userId) async {
    try {
      final image = await _authRepository.getProfilePhoto();
      final current = state;
      if (isClosed || current == null || current.uid != userId) return;
      emit(current.copyWith(profilePhotoBytes: image));
    } catch (error) {
      debugPrint('Gagal memuat foto profil dari Firestore: $error');
    }
  }

  Future<void> _initializeMonthlyBudget(String userId) async {
    if (_budgetUserId == userId) return;
    _budgetUserId = userId;

    final oldSubscription = _budgetSubscription;
    _budgetSubscription = null;
    await oldSubscription?.cancel();

    if (isClosed || state?.uid != userId) return;

    try {
      // Akun lama tanpa field monthlyBudget akan mendapat nilai default.
      // Nilai yang sudah ada tidak akan ditimpa oleh ensureBudget.
      final budget = await _monthlyBudgetService.ensureBudget(userId);
      if (isClosed || state?.uid != userId) return;
      _applyMonthlyBudget(userId, budget);

      _budgetSubscription = _monthlyBudgetService
          .watchBudget(userId)
          .listen(
            (value) => _applyMonthlyBudget(userId, value),
            onError: (Object error, StackTrace stackTrace) {
              debugPrint('Gagal memantau anggaran bulanan: $error');
            },
          );
    } catch (error) {
      debugPrint('Gagal memuat anggaran bulanan dari Firestore: $error');
      if (_budgetUserId == userId) _budgetUserId = null;
    }
  }

  void _applyMonthlyBudget(String userId, int budget) {
    final current = state;
    if (isClosed ||
        current == null ||
        current.uid != userId ||
        current.monthlyBudget == budget) {
      return;
    }
    emit(current.copyWith(monthlyBudget: budget));
  }

  void _cancelMonthlyBudgetWatch() {
    _budgetUserId = null;
    final subscription = _budgetSubscription;
    _budgetSubscription = null;
    if (subscription != null) unawaited(subscription.cancel());
  }

  /// Menyimpan budget ke Firestore dan langsung memperbarui AuthUser.
  Future<String?> updateMonthlyBudget(int budget) async {
    if (budget <= 0) return 'Batas anggaran harus lebih dari Rp0.';

    final userId = state?.uid;
    if (userId == null) return 'Sesi berakhir. Silakan masuk kembali.';

    try {
      await _monthlyBudgetService.updateBudget(userId, budget);
      if (!isClosed && state?.uid == userId) {
        _applyMonthlyBudget(userId, budget);
      }
      return null;
    } on FirebaseException catch (error) {
      // Tampilkan penyebab yang sebenarnya dari Firestore di log.
      debugPrint(
        'Gagal menyimpan anggaran bulanan. '
        'code: ${error.code}, message: ${error.message}',
      );

      return switch (error.code) {
        'permission-denied' =>
          'Firestore menolak penyimpanan anggaran. Periksa Security Rules '
              'pada users/{uid} agar pengguna dapat mengubah field monthlyBudget.',
        'unauthenticated' => 'Sesi Firebase berakhir. Silakan masuk kembali.',
        'unavailable' || 'deadline-exceeded' => 'Firestore sedang tidak dapat dijangkau. Periksa koneksi lalu coba lagi.',
        'failed-precondition' =>
          'Firestore belum memenuhi prasyarat untuk menyimpan anggaran: '
              '${error.message ?? error.code}',
        _ =>
          'Gagal menyimpan anggaran (${error.code}): '
              '${error.message ?? 'Terjadi kesalahan Firestore.'}',
      };
    } catch (error, stackTrace) {
      debugPrint('Gagal menyimpan anggaran bulanan: $error');
      debugPrintStack(stackTrace: stackTrace);
      return 'Anggaran gagal disimpan karena kesalahan aplikasi. Periksa log debug untuk detailnya.';
    }
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

  Future<bool> ensureVerifiedSession() async {
    final user = await _authRepository.validateRemoteAccount(
      refreshVerifiedToken: true,
    );
    if (!isClosed) _set(user);
    if (user?.emailVerified == true) {
      await _loadProfilePhoto(user!.uid);
    }
    return user?.emailVerified == true;
  }

  Future<String?> updatePhoto(Uint8List imageData) async {
    final error = await _authRepository.updatePhoto(imageData);
    if (error == null && state != null) {
      await _loadProfilePhoto(state!.uid);
    }
    return error;
  }

  @override
  Future<void> close() async {
    WidgetsBinding.instance.removeObserver(this);
    _accountCheckTimer.cancel();
    await _authSubscription.cancel();
    await _budgetSubscription?.cancel();
    _tick.dispose();
    await super.close();
  }
}
