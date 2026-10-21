import 'dart:typed_data';

class AuthUser {
  static const int defaultMonthlyBudget = 1500000;
  static const Object _unset = Object();

  final String uid;
  final String? email;
  final String? displayName;
  final bool emailVerified;
  final Uint8List? profilePhotoBytes;
  final int monthlyBudget;

  const AuthUser({
    required this.uid,
    required this.emailVerified,
    this.email,
    this.displayName,
    this.profilePhotoBytes,
    this.monthlyBudget = defaultMonthlyBudget,
  });

  AuthUser copyWith({
    Object? profilePhotoBytes = _unset,
    int? monthlyBudget,
  }) => AuthUser(
    uid: uid,
    email: email,
    displayName: displayName,
    emailVerified: emailVerified,
    profilePhotoBytes: identical(profilePhotoBytes, _unset)
        ? this.profilePhotoBytes
        : profilePhotoBytes as Uint8List?,
    monthlyBudget: monthlyBudget ?? this.monthlyBudget,
  );
}
