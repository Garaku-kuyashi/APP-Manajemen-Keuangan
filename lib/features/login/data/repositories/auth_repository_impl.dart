import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'package:flutter/foundation.dart';

import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final firebase.FirebaseAuth _firebaseAuth;

  AuthRepositoryImpl(this._firebaseAuth);

  AuthUser? _toAuthUser(firebase.User? user) {
    if (user == null) return null;
    return AuthUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      emailVerified: user.emailVerified,
      photoUrl: user.photoURL,
      phoneNumber: user.phoneNumber,
    );
  }

  @override
  AuthUser? get currentUser => _toAuthUser(_firebaseAuth.currentUser);

  @override
  Stream<AuthUser?> get authStateChanges =>
      _firebaseAuth.userChanges().map<AuthUser?>((user) => _toAuthUser(user));

  @override
  Future<String?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return 'Akun berhasil dibuat, tetapi profil pengguna tidak ditemukan.';
      }

      await user.updateDisplayName(name.trim());
      await user.reload();
      await _firebaseAuth.currentUser?.sendEmailVerification();
      return null;
    } on firebase.FirebaseAuthException catch (error) {
      return _errorMessage(error);
    }
  }

  @override
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.reload();

      final refreshedUser = _firebaseAuth.currentUser;
      if (refreshedUser?.emailVerified == true) {
        await refreshedUser!.getIdToken(true);
      }
      return null;
    } on firebase.FirebaseAuthException catch (error) {
      return _errorMessage(error);
    }
  }

  @override
  Future<String?> logout() async {
    try {
      await _firebaseAuth.signOut();
      return null;
    } on firebase.FirebaseAuthException catch (error) {
      return _errorMessage(error);
    }
  }

  @override
  Future<String?> resendVerificationEmail() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        return 'Silakan masuk kembali untuk meminta email verifikasi.';
      }
      await user.sendEmailVerification();
      return null;
    } on firebase.FirebaseAuthException catch (error) {
      return _errorMessage(error);
    }
  }

  @override
  Future<String?> refreshEmailVerification() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return 'Sesi berakhir. Silakan masuk kembali.';

      await user.reload();
      final refreshedUser = _firebaseAuth.currentUser;
      if (refreshedUser?.emailVerified == true) {
        await refreshedUser!.getIdToken(true);
        return null;
      }
      return 'Email belum terverifikasi. Periksa kotak masuk Anda.';
    } on firebase.FirebaseAuthException catch (error) {
      if (_isInvalidAccountCode(error.code)) {
        await _firebaseAuth.signOut();
        return 'Akun tidak lagi tersedia. Silakan masuk kembali.';
      }
      return _errorMessage(error);
    }
  }

  @override
  Future<AuthUser?> validateRemoteAccount({
    bool refreshVerifiedToken = false,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;

    try {
      final wasEmailVerified = user.emailVerified;
      await user.reload();
      final refreshedUser = _firebaseAuth.currentUser;
      if (refreshedUser?.emailVerified == true &&
          (!wasEmailVerified || refreshVerifiedToken)) {
        await refreshedUser!.getIdToken(true);
      }
      return _toAuthUser(_firebaseAuth.currentUser);
    } on firebase.FirebaseAuthException catch (error) {
      if (_isInvalidAccountCode(error.code)) {
        await _firebaseAuth.signOut();
        return null;
      }
      rethrow;
    } catch (error) {
      debugPrint('Validasi akun Firebase gagal: $error');
      rethrow;
    }
  }

  static String _errorMessage(firebase.FirebaseAuthException error) {
    return switch (error.code) {
      'invalid-email' => 'Format email tidak valid.',
      'user-disabled' => 'Akun ini telah dinonaktifkan.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'Email atau kata sandi salah.',
      'email-already-in-use' => 'Email sudah terdaftar.',
      'weak-password' => 'Kata sandi terlalu lemah.',
      'operation-not-allowed' =>
        'Metode email/kata sandi belum diaktifkan di Firebase.',
      'too-many-requests' =>
        'Terlalu banyak percobaan. Coba lagi beberapa saat nanti.',
      'network-request-failed' =>
        'Tidak dapat terhubung. Periksa koneksi internet Anda.',
      'expired-action-code' || 'invalid-action-code' =>
        'Tautan verifikasi tidak valid atau sudah kedaluwarsa.',
      _ => error.message ?? 'Autentikasi gagal. Silakan coba lagi.',
    };
  }

  static bool _isInvalidAccountCode(String code) => const {
    'user-not-found',
    'user-disabled',
    'user-token-expired',
    'invalid-user-token',
  }.contains(code);

  @override
  Future<String?> updateDisplayName(String name) async {
    try {
      final trimmedName = name.trim();

      if (trimmedName.isEmpty) {
        return 'Nama tidak boleh kosong.';
      }

      final user = _firebaseAuth.currentUser;

      if (user == null) {
        return 'Sesi berakhir. Silakan masuk kembali.';
      }

      await user.updateDisplayName(trimmedName);
      await user.reload();

      return null;
    } on firebase.FirebaseAuthException catch (error) {
      return _errorMessage(error);
    } catch (error) {
      debugPrint('Gagal memperbarui nama profil: $error');
      return 'Nama profil gagal diperbarui. Silakan coba lagi.';
    }
  }
}
