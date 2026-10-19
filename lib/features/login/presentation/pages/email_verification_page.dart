import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/auth_cubit.dart';

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
    if (!mounted) return;
    if (error == null) return;

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
                    'Kami mengirim tautan verifikasi ke ${email ?? 'alamat email Anda.'}. Periksa bagian spam jika tidak menemukan email pada inbox. '
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
