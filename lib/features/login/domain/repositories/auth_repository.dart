import '../entities/auth_user.dart';

abstract class AuthRepository {
  AuthUser? get currentUser;

  Stream<AuthUser?> get authStateChanges;

  Future<String?> register({
    required String name,
    required String email,
    required String password,
  });

  Future<String?> login({required String email, required String password});

  Future<String?> logout();

  Future<String?> resendVerificationEmail();

  Future<String?> refreshEmailVerification();

  Future<AuthUser?> validateRemoteAccount({bool refreshVerifiedToken = false});

  Future<String?> updateDisplayName(String name);
}
