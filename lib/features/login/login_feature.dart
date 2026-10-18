import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
// 1. LOGIKA
// ============================================================

class AuthUser {
  final String username;
  const AuthUser(this.username);
}

/// State = user yang sedang login, atau null jika belum login.
/// login() dan register() mengembalikan pesan error, atau null jika berhasil.
class AuthCubit extends Cubit<AuthUser?> {
  static const _accountsKey = 'auth_accounts';
  static const _sessionKey = 'auth_session_user';

  final SharedPreferences _prefs;
  final ValueNotifier<int> _tick = ValueNotifier(0);

  AuthCubit(SharedPreferences prefs)
      : _prefs = prefs,
        super(_restore(prefs));

  bool get isLoggedIn => state != null;

  /// Untuk GoRouter.refreshListenable.
  Listenable get listenable => _tick;

  /// Untuk GoRouter.redirect.
  String? redirect(BuildContext context, GoRouterState state) {
    final path = state.matchedLocation;
    final onAuthPage = path == '/login' || path == '/register';
    if (!isLoggedIn) return onAuthPage ? null : '/login';
    return onAuthPage ? '/' : null;
  }

  Future<String?> register(String username, String password) async {
    final key = _normalize(username);
    final accounts = _accounts(_prefs);
    if (accounts.containsKey(key)) {
      return 'Username sudah dipakai. Pilih yang lain.';
    }

    final random = Random.secure();
    final salt = base64UrlEncode(List.generate(16, (_) => random.nextInt(256)));
    accounts[key] = {'salt': salt, 'hash': _hash(password, salt)};

    await _prefs.setString(_accountsKey, jsonEncode(accounts));
    await _prefs.setString(_sessionKey, key);
    _set(AuthUser(key));
    return null;
  }

  Future<String?> login(String username, String password) async {
    final key = _normalize(username);
    final account = _accounts(_prefs)[key] as Map?;

    // Pesan sama untuk username salah maupun sandi salah.
    if (account == null ||
        _hash(password, account['salt'] as String) != account['hash']) {
      return 'Username atau kata sandi salah.';
    }

    await _prefs.setString(_sessionKey, key);
    _set(AuthUser(key));
    return null;
  }

  Future<void> logout() async {
    await _prefs.remove(_sessionKey);
    _set(null);
  }

  void _set(AuthUser? user) {
    emit(user);
    _tick.value++; // beri tahu router setelah state benar-benar berubah
  }

  @override
  Future<void> close() {
    _tick.dispose();
    return super.close();
  }

  /// Username tidak peka huruf besar/kecil: "Budi" dan "budi" sama.
  static String _normalize(String username) => username.trim().toLowerCase();

  static Map<String, dynamic> _accounts(SharedPreferences p) {
    final raw = p.getString(_accountsKey);
    return raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  static AuthUser? _restore(SharedPreferences p) {
    final username = p.getString(_sessionKey);
    if (username == null) return null;
    return _accounts(p).containsKey(username) ? AuthUser(username) : null;
  }

  static String _hash(String password, String salt) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();
}

// ============================================================
// 2. RUTE
// ============================================================

final authRoutes = <RouteBase>[
  GoRoute(path: '/login', builder: (_, __) => const AuthPage()),
  GoRoute(path: '/register', builder: (_, __) => const AuthPage(register: true)),
];

// ============================================================
// 3. UI
// ============================================================

class AuthPage extends StatefulWidget {
  final bool register;
  const AuthPage({super.key, this.register = false});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  static final _usernameRe = RegExp(r'^[a-zA-Z0-9_.]{3,20}$');

  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _hide = true;

  @override
  void dispose() {
    _username.dispose();
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
        ? await cubit.register(_username.text, _pass.text)
        : await cubit.login(_username.text, _pass.text);

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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: !_loading,
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
                  tooltip: _hide ? 'Tampilkan kata sandi' : 'Sembunyikan kata sandi',
                  icon: Icon(_hide
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
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
                      Icon(Icons.account_balance_wallet_outlined,
                          size: 48, color: theme.colorScheme.primary),
                      const SizedBox(height: 16),
                      Text(
                        reg ? 'Buat akun MyMoney' : 'Masuk ke MyMoney',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 24),
                      _field(_username, 'Username', Icons.person_outline,
                          hints: [
                            reg
                                ? AutofillHints.newUsername
                                : AutofillHints.username
                          ],
                          validator: (v) {
                            final value = (v ?? '').trim();
                            if (value.isEmpty) return 'Username wajib diisi.';
                            if (reg && !_usernameRe.hasMatch(value)) {
                              return '3–20 karakter: huruf, angka, titik, atau garis bawah.';
                            }
                            return null;
                          }),
                      _field(_pass, 'Kata sandi', Icons.lock_outline,
                          secret: true,
                          last: !reg,
                          hints: [
                            reg
                                ? AutofillHints.newPassword
                                : AutofillHints.password
                          ],
                          validator: (v) => reg
                              ? ((v ?? '').length < 8
                                  ? 'Kata sandi minimal 8 karakter.'
                                  : null)
                              : ((v ?? '').isEmpty
                                  ? 'Kata sandi wajib diisi.'
                                  : null)),
                      if (reg)
                        _field(_confirm, 'Ulangi kata sandi', Icons.lock_outline,
                            secret: true,
                            last: true,
                            validator: (v) =>
                                v != _pass.text ? 'Kata sandi tidak sama.' : null),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _loading ? null : _submit,
                        style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48)),
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
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
                                : () => context.go(reg ? '/login' : '/register'),
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
