import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mymoney/core/utils/currency_formatter.dart';
import 'package:mymoney/features/login/presentation/cubit/auth_cubit.dart';

import '../../../../core/di/theme/app_colors.dart';
import '../../../../core/di/theme/app_icons.dart';
import 'settings_page.dart';
import '../../../transaction/presentation/cubit/transaction_cubit.dart';
import '../../../transaction/presentation/cubit/transaction_state.dart';
import '../../../wallet/presentation/cubit/wallet_cubit.dart';
import '../../../wallet/presentation/cubit/wallet_state.dart';
import '../../../wallet/presentation/pages/wallet_page.dart';

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
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark
              ? AppColors.surface
              : AppColors.lightBackgroundCard,
          title: Text(
            'Atur Batas Anggaran Bulanan',
            style: TextStyle(
              color: isDark ? AppColors.textPrimary : AppColors.primaryText,
            ),
          ),
          content: TextField(
            controller: budgetCtrl,
            keyboardType: TextInputType.number,
            style: TextStyle(
              color: isDark ? AppColors.textPrimary : AppColors.primaryText,
            ),
            decoration: InputDecoration(
              labelText: 'Batas Budget (Rp)',
              hintText: 'Misal: 2000000',
              filled: true,
              fillColor: isDark
                  ? AppColors.background
                  : AppColors.lightInputBackground,
              labelStyle: TextStyle(
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.secondaryText,
              ),
              hintStyle: TextStyle(
                color: isDark
                    ? AppColors.textSecondary
                    : AppColors.secondaryText,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
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
                      backgroundColor: AppColors.positive,
                    ),
                  );
                }
                Navigator.pop(ctx);
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
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
        builder: (dialogCtx) {
          final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark
                ? AppColors.surface
                : AppColors.lightBackgroundCard,
            title: Text(
              'Ekspor Data Transaksi (CSV)',
              style: TextStyle(
                color: isDark ? AppColors.textPrimary : AppColors.primaryText,
              ),
            ),
            content: SingleChildScrollView(
              child: SelectableText(
                csvData,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: isDark ? AppColors.textPrimary : AppColors.primaryText,
                ),
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
                      backgroundColor: AppColors.positive,
                    ),
                  );
                  Navigator.pop(dialogCtx);
                },
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Salin Data'),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().currentUser;
    final userName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!
        : 'Pengguna';

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBackground = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final navigationColor = isDark
        ? AppColors.surface
        : AppColors.lightBackgroundCard;
    final cardColor = isDark
        ? AppColors.surface
        : AppColors.lightBackgroundCard;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.primaryText;
    final secondaryText = isDark
        ? AppColors.textSecondary
        : AppColors.secondaryText;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final dividerColor = isDark ? AppColors.divider : AppColors.lightGray;

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        title: Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text('Profile', style: TextStyle(color: primaryText)),
        ),
        backgroundColor: navigationColor,
        foregroundColor: primaryText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Pengaturan',
            icon: const Icon(AppIcons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: IconButton(
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
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // KARTU PROFIL INTERAKTIF
            Card(
              color: cardColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: borderColor, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.accentBlue,
                      child: Icon(Icons.person, size: 38, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: TextStyle(
                              color: primaryText,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Chip(
                            backgroundColor: isDark
                                ? AppColors.background
                                : AppColors.lightGray,
                            label: Text(
                              'Mahasiswa Hemat 🛡️',
                              style: TextStyle(
                                fontSize: 10,
                                color: primaryText,
                              ),
                            ),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        AppIcons.edit,
                        color: AppColors.accentBlue,
                      ),
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
                    color: cardColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: borderColor, width: 1),
                    ),
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
                                style: TextStyle(
                                  color: primaryText,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                          Text(
                            'Transaksi',
                            style: TextStyle(
                              fontSize: 11,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    color: cardColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: borderColor, width: 1),
                    ),
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
                                style: TextStyle(
                                  color: primaryText,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                          Text(
                            'Dompet Kas',
                            style: TextStyle(
                              fontSize: 11,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                'Manajemen Keuangan',
                style: TextStyle(
                  color: primaryText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 8),

            Card(
              color: cardColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: borderColor, width: 1),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: AppColors.accentBlue,
                    ),
                    title: Text(
                      'Kelola Dompet',
                      style: TextStyle(color: primaryText),
                    ),
                    subtitle: Text(
                      'Lihat dan atur dompet keuangan Anda',
                      style: TextStyle(color: secondaryText),
                    ),
                    trailing: Icon(Icons.chevron_right, color: secondaryText),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WalletPage()),
                    ),
                  ),
                  Divider(height: 1, color: dividerColor),
                  ListTile(
                    leading: const Icon(
                      Icons.track_changes,
                      color: AppColors.accentBlue,
                    ),
                    title: Text(
                      'Atur Batas Anggaran Bulanan',
                      style: TextStyle(color: primaryText),
                    ),
                    subtitle: Text(
                      'Target: ${CurrencyFormatter.format(_userBudget)} / bulan',
                      style: TextStyle(color: secondaryText),
                    ),
                    trailing: Icon(Icons.chevron_right, color: secondaryText),
                    onTap: _showSetBudgetDialog,
                  ),
                  Divider(height: 1, color: dividerColor),
                  ListTile(
                    leading: const Icon(
                      Icons.download_outlined,
                      color: AppColors.accentBlue,
                    ),
                    title: Text(
                      'Ekspor Laporan Transaksi',
                      style: TextStyle(color: primaryText),
                    ),
                    subtitle: Text(
                      'Salin format CSV untuk LPJ',
                      style: TextStyle(color: secondaryText),
                    ),
                    trailing: Icon(Icons.chevron_right, color: secondaryText),
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

  const _EditProfileDialog({required this.initialName, required this.onSave});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.primaryText;
    final secondaryText = isDark
        ? AppColors.textSecondary
        : AppColors.secondaryText;

    return AlertDialog(
      backgroundColor: isDark
          ? AppColors.surface
          : AppColors.lightBackgroundCard,
      title: Text('Edit Nama Profil', style: TextStyle(color: primaryText)),
      content: TextField(
        controller: _nameController,
        autofocus: true,
        enabled: !_saving,
        textCapitalization: TextCapitalization.words,
        style: TextStyle(color: primaryText),
        decoration: InputDecoration(
          labelText: 'Nama Lengkap',
          hintText: 'Masukkan nama lengkap',
          prefixIcon: const Icon(Icons.person_outline),
          errorText: _error,
          filled: true,
          fillColor: isDark
              ? AppColors.background
              : AppColors.lightInputBackground,
          labelStyle: TextStyle(color: secondaryText),
          hintStyle: TextStyle(color: secondaryText),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: AppColors.accentBlue),
          ),
        ),
        onChanged: (_) {
          if (_error != null) {
            setState(() => _error = null);
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
