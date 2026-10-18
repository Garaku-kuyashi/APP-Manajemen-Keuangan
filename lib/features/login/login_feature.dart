import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class AuthCubit extends Cubit<User?> with WidgetsBindingObserver {
  final FirebaseAuth _firebaseAuth;
  final ValueNotifier<int> _tick = ValueNotifier(0);
  late final StreamSubscription<User?> _authSubscription;
  late final Timer _accountCheckTimer;
  bool _checkingRemoteAccount = false;
  bool _receivedInitialAuthState = false;

  AuthCubit(FirebaseAuth firebaseAuth)
    : _firebaseAuth = firebaseAuth,
      super(firebaseAuth.currentUser) {
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = _firebaseAuth.userChanges().listen(_onAuthStateChanged);
    _accountCheckTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => unawaited(_validateRemoteAccount()),
    );
  }

  bool get isLoggedIn => state != null;

  /// Untuk GoRouter.refreshListenable.
  Listenable get listenable => _tick;

  /// Untuk GoRouter.redirect.
  String? redirect(BuildContext context, GoRouterState state) {
    final path = state.matchedLocation;
    final onAuthPage = path == '/login' || path == '/register';
    if (!isLoggedIn) return onAuthPage ? null : '/login';
    if (path == '/verify-email' && this.state?.emailVerified == true) {
      return '/';
    }
    if (this.state?.emailVerified != true) {
      return path == '/verify-email' ? null : '/verify-email';
    }
    return onAuthPage ? '/' : null;
  }

  Future<String?> register(String email, String password) async {
    try {
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _firebaseAuth.currentUser!.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (error) {
      return _errorMessage(error);
    }
  }

  Future<String?> login(String email, String password) async {
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
      _set(_firebaseAuth.currentUser);
      return null;
    } on FirebaseAuthException catch (error) {
      return _errorMessage(error);
    }
  }

  Future<String?> logout() async {
    try {
      await _firebaseAuth.signOut();
      _set(null);
      return null;
    } on FirebaseAuthException catch (error) {
      return _errorMessage(error);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_validateRemoteAccount());
    }
  }

  Future<void> _validateRemoteAccount({
    bool refreshVerifiedToken = false,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null || _checkingRemoteAccount || isClosed) return;

    _checkingRemoteAccount = true;
    try {
      final wasEmailVerified = user.emailVerified;
      await user.reload();
      final refreshedUser = _firebaseAuth.currentUser;
      if (refreshedUser?.emailVerified == true &&
          (!wasEmailVerified || refreshVerifiedToken)) {
        await refreshedUser!.getIdToken(true);
      }
      if (!isClosed) _set(_firebaseAuth.currentUser);
    } on FirebaseAuthException catch (error) {
      if (_isInvalidAccountCode(error.code)) {
        await _firebaseAuth.signOut();
        if (!isClosed) _set(null);
      } else {
        debugPrint('Firebase account validation failed: ${error.code}');
      }
    } finally {
      _checkingRemoteAccount = false;
    }
  }

  Future<String?> resendVerificationEmail() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        return 'Silakan masuk kembali untuk meminta email verifikasi.';
      }
      await user.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (error) {
      return _errorMessage(error);
    }
  }

  Future<String?> refreshEmailVerification() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return 'Sesi berakhir. Silakan masuk kembali.';
      await user.reload();
      final refreshedUser = _firebaseAuth.currentUser;
      if (refreshedUser?.emailVerified == true) {
        await refreshedUser!.getIdToken(true);
      }
      _set(refreshedUser);
      return refreshedUser?.emailVerified == true
          ? null
          : 'Email belum terverifikasi. Periksa kotak masuk Anda.';
    } on FirebaseAuthException catch (error) {
      if (_isInvalidAccountCode(error.code)) {
        await _firebaseAuth.signOut();
        _set(null);
        return 'Akun tidak lagi tersedia. Silakan masuk kembali.';
      }
      return _errorMessage(error);
    }
  }

  static String _errorMessage(FirebaseAuthException error) {
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

  void _set(User? user) {
    emit(user);
    _tick.value++;
  }

  void _onAuthStateChanged(User? user) {
    _set(user);
    if (!_receivedInitialAuthState) {
      _receivedInitialAuthState = true;
      if (user != null) {
        unawaited(_validateRemoteAccount(refreshVerifiedToken: true));
      }
    }
  }

  static bool _isInvalidAccountCode(String code) => const {
    'user-not-found',
    'user-disabled',
    'user-token-expired',
    'invalid-user-token',
  }.contains(code);

  @override
  Future<void> close() async {
    WidgetsBinding.instance.removeObserver(this);
    _accountCheckTimer.cancel();
    await _authSubscription.cancel();
    _tick.dispose();
    await super.close();
  }
}

final authRoutes = <RouteBase>[
  GoRoute(path: '/login', builder: (_, _) => const AuthPage()),
  GoRoute(path: '/register', builder: (_, _) => const AuthPage(register: true)),
  GoRoute(
    path: '/verify-email',
    builder: (_, _) => const EmailVerificationPage(),
  ),
];

class AuthPage extends StatefulWidget {
  final bool register;
  const AuthPage({super.key, this.register = false});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool _loading = false;

  Future<void> _logout() async {
    if (_loading) return;
    setState(() => _loading = true);
    final error = await context.read<AuthCubit>().logout();
    if (!mounted || error == null) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _run(
    Future<String?> Function() action, {
    required bool resend,
  }) async {
    if (_loading) return;
    setState(() => _loading = true);
    final error = await action();
    if (!mounted) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            error ??
                (resend
                    ? 'Email verifikasi berhasil dikirim.'
                    : 'Email berhasil diverifikasi.'),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final email = context.select<AuthCubit, String?>(
      (cubit) => cubit.state?.email,
    );

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.mark_email_unread_outlined,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Verifikasi email Anda',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Kami mengirim tautan verifikasi ke ${email ?? 'alamat email Anda'}. '
                    'Buka tautan tersebut, lalu kembali ke aplikasi.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _loading
                        ? null
                        : () => _run(
                            context.read<AuthCubit>().refreshEmailVerification,
                            resend: false,
                          ),
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Saya sudah memverifikasi'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _loading
                        ? null
                        : () => _run(
                            context.read<AuthCubit>().resendVerificationEmail,
                            resend: true,
                          ),
                    child: const Text('Kirim ulang email verifikasi'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _loading ? null : _logout,
                    child: const Text('Keluar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthPageState extends State<AuthPage> {
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _hide = true;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final cubit = context.read<AuthCubit>();
    final error = widget.register
        ? await cubit.register(_email.text, _pass.text)
        : await cubit.login(_email.text, _pass.text);

    // Jika berhasil, router otomatis pindah ke dashboard.
    if (!mounted || error == null) return;
    setState(() => _loading = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(error)));
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    String? Function(String?)? validator,
    bool secret = false,
    bool last = false,
    Iterable<String>? hints,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: !_loading,
        keyboardType: keyboardType,
        textCapitalization: TextCapitalization.none,
        obscureText: secret && _hide,
        autocorrect: false,
        enableSuggestions: false,
        textInputAction: last ? TextInputAction.done : TextInputAction.next,
        autofillHints: hints,
        validator: validator,
        onFieldSubmitted: last ? (_) => _submit() : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
          suffixIcon: secret
              ? IconButton(
                  tooltip: _hide
                      ? 'Tampilkan kata sandi'
                      : 'Sembunyikan kata sandi',
                  icon: Icon(
                    _hide
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _hide = !_hide),
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reg = widget.register;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        reg ? 'Buat akun MyMoney' : 'Masuk ke MyMoney',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _field(
                        _email,
                        'Email',
                        Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        hints: [AutofillHints.email],
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'Email wajib diisi.';
                          if (!_emailRe.hasMatch(value)) {
                            return 'Masukkan alamat email yang valid.';
                          }
                          return null;
                        },
                      ),
                      _field(
                        _pass,
                        'Kata sandi',
                        Icons.lock_outline,
                        secret: true,
                        last: !reg,
                        hints: [
                          reg
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        validator: (v) => reg
                            ? ((v ?? '').length < 8
                                  ? 'Kata sandi minimal 8 karakter.'
                                  : null)
                            : ((v ?? '').isEmpty
                                  ? 'Kata sandi wajib diisi.'
                                  : null),
                      ),
                      if (reg)
                        _field(
                          _confirm,
                          'Ulangi kata sandi',
                          Icons.lock_outline,
                          secret: true,
                          last: true,
                          validator: (v) =>
                              v != _pass.text ? 'Kata sandi tidak sama.' : null,
                        ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(reg ? 'Daftar' : 'Masuk'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(reg ? 'Sudah punya akun?' : 'Belum punya akun?'),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () =>
                                      context.go(reg ? '/login' : '/register'),
                            child: Text(reg ? 'Masuk' : 'Daftar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
