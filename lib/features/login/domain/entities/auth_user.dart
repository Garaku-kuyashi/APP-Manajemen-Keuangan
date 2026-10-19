class AuthUser {
  final String uid;
  final String? email;
  final String? displayName;
  final bool emailVerified;
  final String? photoUrl;
  final String? phoneNumber;

  const AuthUser({
    required this.uid,
    required this.emailVerified,
    this.email,
    this.displayName,
    this.photoUrl,
    this.phoneNumber,
  });
}
