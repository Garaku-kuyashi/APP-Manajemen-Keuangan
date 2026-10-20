import 'dart:typed_data';

class AuthUser {
  final String uid;
  final String? email;
  final String? displayName;
  final bool emailVerified;
  final Uint8List? profilePhotoBytes;
  final String? phoneNumber;

  const AuthUser({
    required this.uid,
    required this.emailVerified,
    this.email,
    this.displayName,
    this.profilePhotoBytes,
    this.phoneNumber,
  });

  AuthUser copyWith({Uint8List? profilePhotoBytes}) => AuthUser(
    uid: uid,
    email: email,
    displayName: displayName,
    emailVerified: emailVerified,
    profilePhotoBytes: profilePhotoBytes,
    phoneNumber: phoneNumber,
  );
}
