import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mymoney/features/login/presentation/cubit/auth_cubit.dart';

import '../../../../core/ui/app_icons.dart';
import 'settings_page.dart';
import '../../../transaction/presentation/cubit/transaction_cubit.dart';
import '../../../transaction/presentation/cubit/transaction_state.dart';
import '../../../wallet/presentation/cubit/wallet_cubit.dart';
import '../../../wallet/presentation/cubit/wallet_state.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _userBudget = 1500000;
  bool _loggingOut = false;

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);

    final error = await context.read<AuthCubit>().logout();
    if (!mounted) return;

    if (error != null) {
      setState(() => _loggingOut = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _showEditProfileDialog() async {
    final authCubit = context.read<AuthCubit>();

    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditProfileDialog(
        initialName: authCubit.currentUser?.displayName ?? '',
        onSave: authCubit.updateDisplayName,
      ),
    );

    if (!mounted) return;

    if (updated == true) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Nama profil berhasil diperbarui.')),
        );
    }
  }

  void _showSetBudgetDialog() {
    final budgetCtrl = TextEditingController(text: _userBudget.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Atur Batas Anggaran Bulanan'),
        content: TextField(
          controller: budgetCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Batas Budget (Rp)',
            hintText: 'Misal: 2000000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final newBudget = int.tryParse(budgetCtrl.text.trim());
              if (newBudget != null) {
                setState(() => _userBudget = newBudget);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Batas anggaran berhasil diubah ke Rp $_userBudget',
                    ),
                  ),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context) {
    final state = context.read<TransactionCubit>().state;

    if (state is DataSuccess) {
      final String csvData =
          "Tanggal,Judul,Kategori,Nominal,Tipe,Dompet\n" +
          state.transactions
              .map((tx) {
                return "${tx.date.toString().substring(0, 10)},\"${tx.title}\",${tx.category},${tx.amount},${tx.type.name},${tx.walletName}";
              })
              .join("\n");

      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Ekspor Data Transaksi (CSV)'),
          content: SingleChildScrollView(
            child: SelectableText(
              csvData,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Tutup'),
            ),
            FilledButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Data CSV berhasil disalin!'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pop(dialogCtx);
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Salin Data'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().currentUser;
    final userName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!
        : 'Pengguna';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Pengaturan',
            icon: const Icon(AppIcons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
          IconButton(
            tooltip: 'Keluar',
            icon: _loggingOut
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            onPressed: _loggingOut ? null : _logout,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // KARTU PROFIL INTERAKTIF
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.blueAccent,
                      child: Icon(Icons.person, size: 38, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Chip(
                            label: const Text(
                              'Mahasiswa Hemat 🛡️',
                              style: TextStyle(fontSize: 10),
                            ),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(AppIcons.edit, color: Colors.blueAccent),
                      onPressed: _showEditProfileDialog,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // KARTU RINGKASAN STATISTIK
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          BlocBuilder<TransactionCubit, TransactionState>(
                            builder: (context, state) {
                              final count = state is DataSuccess
                                  ? state.transactions.length
                                  : 0;
                              return Text(
                                '$count',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                          const Text(
                            'Transaksi',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          BlocBuilder<WalletCubit, WalletState>(
                            builder: (context, state) {
                              final count = state is WalletSuccess
                                  ? state.wallets.length
                                  : 0;
                              return Text(
                                '$count',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                          const Text(
                            'Dompet Kas',
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Text(
              'Manajemen Keuangan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),

            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.track_changes,
                      color: Colors.orangeAccent,
                    ),
                    title: const Text('Atur Batas Anggaran Bulanan'),
                    subtitle: Text('Target: Rp $_userBudget / bulan'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showSetBudgetDialog,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.download_outlined,
                      color: Colors.greenAccent,
                    ),
                    title: const Text('Ekspor Laporan Transaksi'),
                    subtitle: const Text('Salin format CSV untuk LPJ'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showExportDialog(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  final String initialName;
  final Future<String?> Function(String name) onSave;

  const _EditProfileDialog({
    required this.initialName,
    required this.onSave,
  });

  @override
  State<_EditProfileDialog> createState() =>
      _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialName,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Nama wajib diisi.');
      return;
    }

    if (name.length < 2) {
      setState(() => _error = 'Nama minimal 2 karakter.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final error = await widget.onSave(name);

      if (!mounted) return;

      if (error != null) {
        setState(() {
          _saving = false;
          _error = error;
        });
        return;
      }

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
        _error = 'Gagal memperbarui nama. Silakan coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Nama Profil'),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        enabled: !_saving,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Nama Lengkap',
          hintText: 'Masukkan nama lengkap',
          prefixIcon: const Icon(Icons.person_outline),
          errorText: _error,
        ),
        onChanged: (_) {
          if (_error != null) {
            setState(() => _error = null);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}