import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../cubit/auth_cubit.dart';

class AuthPage extends StatefulWidget {
  final bool register;

  const AuthPage({super.key, this.register = false});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();

  bool _loading = false;
  bool _hide = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;

    final form = _form.currentState;
    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    try {
      final cubit = context.read<AuthCubit>();

      final error = widget.register
          ? await cubit.register(
              _name.text.trim(),
              _email.text.trim(),
              _pass.text,
            )
          : await cubit.login(_email.text.trim(), _pass.text);

      if (!mounted) return;

      if (error == null) {
        // Navigasi setelah autentikasi ditangani oleh GoRouter.
        setState(() => _loading = false);
        return;
      }

      setState(() => _loading = false);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
        );
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Terjadi kesalahan. Silakan coba lagi.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    required ThemeData theme,
    String? Function(String?)? validator,
    bool secret = false,
    bool last = false,
    Iterable<String>? hints,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: !_loading,
        keyboardType: keyboardType,
        textCapitalization: capitalization,
        obscureText: secret && _hide,
        autocorrect: false,
        enableSuggestions: !secret,
        textInputAction: last ? TextInputAction.done : TextInputAction.next,
        autofillHints: hints,
        validator: validator,
        onFieldSubmitted: last ? (_) => _submit() : null,
        decoration: InputDecoration(
          hintText: label,
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 8, right: 4),
            child: Icon(
              icon,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          suffixIcon: secret
              ? Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    tooltip: _hide
                        ? 'Tampilkan kata sandi'
                        : 'Sembunyikan kata sandi',
                    icon: Icon(
                      _hide
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    onPressed: _loading
                        ? null
                        : () => setState(() => _hide = !_hide),
                  ),
                )
              : null,
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: theme.colorScheme.primary,
              width: 1.2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: theme.colorScheme.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: theme.colorScheme.error, width: 1.2),
          ),
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
            // Padding utama dipertahankan seperti kode awal.
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Ikon di tengah tanpa card pembungkus halaman.
                      Center(
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 38,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Judul halaman.
                      Text(
                        reg ? 'Buat akun MyMoney' : 'Sign In',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Deskripsi.
                      Text(
                        reg
                            ? 'Lengkapi data untuk membuat akun'
                            : 'Silakan masukkan email dan kata sandi',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 36),

                      // Nama hanya untuk registrasi.
                      if (reg)
                        _field(
                          _name,
                          'Nama lengkap',
                          Icons.person_outline,
                          theme: theme,
                          capitalization: TextCapitalization.words,
                          hints: const [AutofillHints.name],
                          validator: (value) {
                            final name = (value ?? '').trim();

                            if (name.isEmpty) {
                              return 'Nama wajib diisi.';
                            }

                            if (name.length < 2) {
                              return 'Nama minimal 2 karakter.';
                            }

                            return null;
                          },
                        ),

                      // Email.
                      _field(
                        _email,
                        'Email',
                        Icons.alternate_email,
                        theme: theme,
                        keyboardType: TextInputType.emailAddress,
                        hints: const [AutofillHints.email],
                        validator: (value) {
                          final email = (value ?? '').trim();

                          if (email.isEmpty) {
                            return 'Email wajib diisi.';
                          }

                          if (!_emailRe.hasMatch(email)) {
                            return 'Masukkan alamat email yang valid.';
                          }

                          return null;
                        },
                      ),

                      // Kata sandi.
                      _field(
                        _pass,
                        'Kata sandi',
                        Icons.lock_outline,
                        theme: theme,
                        secret: true,
                        last: !reg,
                        hints: [
                          reg
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        validator: (value) {
                          final password = value ?? '';

                          if (password.isEmpty) {
                            return 'Kata sandi wajib diisi.';
                          }

                          if (reg && password.length < 8) {
                            return 'Kata sandi minimal 8 karakter.';
                          }

                          return null;
                        },
                      ),

                      // Konfirmasi kata sandi saat registrasi.
                      if (reg)
                        _field(
                          _confirm,
                          'Ulangi kata sandi',
                          Icons.lock_outline,
                          theme: theme,
                          secret: true,
                          last: true,
                          hints: const [AutofillHints.newPassword],
                          validator: (value) {
                            if ((value ?? '').isEmpty) {
                              return 'Konfirmasi kata sandi wajib diisi.';
                            }

                            if (value != _pass.text) {
                              return 'Kata sandi tidak sama.';
                            }

                            return null;
                          },
                        ),

                      const SizedBox(height: 8),

                      // Tombol utama.
                      SizedBox(
                        height: 50,
                        child: FilledButton(
                          onPressed: _loading ? null : _submit,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(reg ? 'Daftar' : 'Sign In'),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Navigasi masuk dan daftar.
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              reg ? 'Sudah punya akun?' : 'Belum punya akun?',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _loading
                                ? null
                                : () =>
                                      context.go(reg ? '/login' : '/register'),
                            child: Text(
                              reg ? 'Masuk' : 'Sign Up',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
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
