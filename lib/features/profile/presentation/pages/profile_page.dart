import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mymoney/core/utils/currency_formatter.dart';
import 'package:mymoney/core/utils/text_input_formatter.dart';
import 'package:mymoney/features/login/presentation/cubit/auth_cubit.dart';
import 'package:mymoney/features/login/domain/entities/auth_user.dart';

import '../../../../core/di/theme/app_colors.dart';
import '../../../../core/di/theme/app_icons.dart';
import 'settings_page.dart';
import '../../../transaction/presentation/cubit/transaction_cubit.dart';
import '../../../transaction/presentation/cubit/transaction_state.dart';
import '../../../wallet/presentation/cubit/wallet_cubit.dart';
import '../../../wallet/presentation/cubit/wallet_state.dart';
import '../../../wallet/presentation/pages/wallet_page.dart';

int? _parseRupiahAmount(String value) {
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return int.tryParse(digits);
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
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
      barrierDismissible: true,
      builder: (_) => _EditProfileDialog(
        initialName: authCubit.currentUser?.displayName ?? '',
        initialPhotoBytes: authCubit.state?.profilePhotoBytes,
        onSave: authCubit.updateDisplayName,
        onPhotoSelected: authCubit.updatePhoto,
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

  Future<void> _showSetBudgetDialog() async {
    final authCubit = context.read<AuthCubit>();
    final currentBudget =
        authCubit.state?.monthlyBudget ?? AuthUser.defaultMonthlyBudget;

    // Controller dimiliki oleh State dialog, bukan oleh halaman ini.
    // Dengan begitu controller tidak di-dispose saat Future showDialog selesai,
    // sementara animasi penutupan dialog dan TextField masih terpasang.
    final savedBudget = await showDialog<int>(
      context: context,
      builder: (_) => _SetMonthlyBudgetDialog(
        initialBudget: currentBudget,
        onSave: authCubit.updateMonthlyBudget,
      ),
    );

    if (!mounted || savedBudget == null) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Batas anggaran berhasil disimpan: ${CurrencyFormatter.format(savedBudget)}',
          ),
          backgroundColor: AppColors.positive,
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
        builder: (dialogCtx) {
          final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;

          return AlertDialog(
            backgroundColor: isDark
                ? AppColors.surface
                : AppColors.lightBackgroundCard,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),

            title: Text(
              'Ekspor Data Transaksi (CSV)',
              style: TextStyle(
                color: isDark ? AppColors.textPrimary : AppColors.primaryText,
              ),
            ),

            content: ConstrainedBox(
              constraints: BoxConstraints(minWidth: 400, maxWidth: 440),
              child: SingleChildScrollView(
                child: SelectableText(
                  csvData,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.primaryText,
                  ),
                ),
              ),
            ),

            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text(
                  'Batal',
                  style: TextStyle(color: AppColors.negative),
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  foregroundColor: Colors.white,
                ),
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
    final user = context.watch<AuthCubit>().state;
    final userName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!
        : 'Pengguna';
    final monthlyBudget = user?.monthlyBudget ?? AuthUser.defaultMonthlyBudget;

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
          padding: const EdgeInsets.all(12),
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
                    _profileAvatar(user?.profilePhotoBytes, 64),
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
                      'Target: ${CurrencyFormatter.format(monthlyBudget)} / bulan',
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

class _SetMonthlyBudgetDialog extends StatefulWidget {
  final int initialBudget;
  final Future<String?> Function(int budget) onSave;

  const _SetMonthlyBudgetDialog({
    required this.initialBudget,
    required this.onSave,
  });

  @override
  State<_SetMonthlyBudgetDialog> createState() =>
      _SetMonthlyBudgetDialogState();
}

class _SetMonthlyBudgetDialogState extends State<_SetMonthlyBudgetDialog> {
  late final TextEditingController _budgetController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _budgetController = TextEditingController(
      text: CurrencyFormatter.formatWithoutSymbol(widget.initialBudget),
    );
  }

  @override
  void dispose() {
    // Dialog State yang memiliki controller, sehingga disposal mengikuti
    // lifecycle TextField setelah route dialog benar-benar dilepas.
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;

    final newBudget = _parseRupiahAmount(_budgetController.text);
    if (newBudget == null || newBudget <= 0) {
      setState(() {
        _error = 'Masukkan nominal anggaran yang valid dan lebih dari Rp0.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final error = await widget.onSave(newBudget);
      if (!mounted) return;

      if (error != null) {
        setState(() {
          _saving = false;
          _error = error;
        });
        return;
      }

      Navigator.of(context).pop(newBudget);
    } catch (error, stackTrace) {
      debugPrint('Gagal menyimpan batas anggaran: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;

      setState(() {
        _saving = false;
        _error = 'Anggaran gagal disimpan. Silakan coba lagi.';
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
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Atur Batas Anggaran Bulanan',
        style: TextStyle(color: primaryText),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 400, maxWidth: 440),
        child: SingleChildScrollView(
          child: TextField(
            maxLength: 18,
            enabled: !_saving,
            inputFormatters: [RupiahInputFormatter()],
            controller: _budgetController,
            keyboardType: TextInputType.number,
            style: TextStyle(color: primaryText),
            decoration: InputDecoration(
              labelText: 'Batas Budget (Rp)',
              hintText: 'Misal: 2000000',
              errorText: _error,
              filled: true,
              fillColor: isDark
                  ? AppColors.surface
                  : AppColors.lightBackgroundCard,
              labelStyle: TextStyle(color: secondaryText),
              hintStyle: TextStyle(color: secondaryText),
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
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: AppColors.accentBlue),
              ),
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text(
            'Batal',
            style: TextStyle(color: AppColors.negative),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accentBlue,
            foregroundColor: Colors.white,
          ),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  final String initialName;
  final Uint8List? initialPhotoBytes;
  final Future<String?> Function(String name) onSave;
  final Future<String?> Function(Uint8List imageData) onPhotoSelected;

  const _EditProfileDialog({
    required this.initialName,
    required this.initialPhotoBytes,
    required this.onSave,
    required this.onPhotoSelected,
  });

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;

  bool _saving = false;
  bool _uploadingPhoto = false;
  bool _photoSaved = false;
  String? _error;
  Uint8List? _photoBytes;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _photoBytes = widget.initialPhotoBytes;
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

  Future<void> _pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 15 * 1024 * 1024) {
        setState(() => _error = 'Ukuran file gambar maksimal 15 MB.');
        return;
      }

      setState(() {
        _photoBytes = bytes;
        _uploadingPhoto = true;
        _photoSaved = false;
        _error = null;
      });

      try {
        final error = await widget.onPhotoSelected(bytes);
        if (!mounted) return;
        setState(() {
          _error = error;
          _photoSaved = error == null;
          if (error != null) _photoBytes = null;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _error = 'Foto profil gagal diperbarui: $error';
          _photoBytes = null;
        });
      } finally {
        if (mounted) setState(() => _uploadingPhoto = false);
      }
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _uploadingPhoto = false;
        _error = 'Foto gagal dipilih atau diunggah: $error';
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
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),

      title: Text('Edit Profil', style: TextStyle(color: primaryText)),

      content: ConstrainedBox(
        constraints: BoxConstraints(minWidth: 400, maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  _photoBytes == null
                      ? _profileAvatar(widget.initialPhotoBytes, 88)
                      : ClipOval(
                          child: Image.memory(
                            _photoBytes!,
                            width: 88,
                            height: 88,
                            fit: BoxFit.cover,
                          ),
                        ),
                  IconButton.filled(
                    tooltip: 'Pilih foto profil',
                    onPressed: _uploadingPhoto || _saving ? null : _pickPhoto,
                    icon: _uploadingPhoto
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.camera_alt_outlined, size: 18),
                  ),
                ],
              ),

              if (_photoSaved)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Foto profil berhasil diperbarui.',
                    style: TextStyle(color: AppColors.positive, fontSize: 12),
                  ),
                ),

              const SizedBox(height: 28),

              TextField(
                controller: _nameController,
                autofocus: true,
                enabled: !_saving && !_uploadingPhoto,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(color: primaryText),
                decoration: InputDecoration(
                  labelText: 'Nama Lengkap',
                  hintText: 'Masukkan nama lengkap',
                  prefixIcon: const Icon(Icons.person_outline),
                  errorText: _error,
                  filled: true,
                  fillColor: isDark
                      ? AppColors.surface
                      : AppColors.lightBackgroundCard,
                  labelStyle: TextStyle(color: secondaryText),
                  hintStyle: TextStyle(color: secondaryText),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: isDark
                          ? AppColors.darkBorder
                          : AppColors.lightBorder,
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
            ],
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text(
            'Batal',
            style: TextStyle(color: AppColors.negative),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accentBlue,
            foregroundColor: Colors.white,
          ),
          onPressed: _saving || _uploadingPhoto ? null : _save,
          child: _saving || _uploadingPhoto
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}

Widget _profileAvatar(Uint8List? photoBytes, double size) {
  if (photoBytes == null || photoBytes.isEmpty) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.accentBlue,
      child: Icon(Icons.person, size: size * 0.6, color: Colors.white),
    );
  }

  return ClipOval(
    child: Image.memory(
      photoBytes,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => CircleAvatar(
        radius: size / 2,
        backgroundColor: AppColors.accentBlue,
        child: Icon(Icons.person, size: size * 0.6, color: Colors.white),
      ),
    ),
  );
}
