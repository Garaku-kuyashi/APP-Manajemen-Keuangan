
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mymoney/core/utils/currency_formatter.dart';

import '../../../../core/di/theme/app_colors.dart';
import '../../../../core/di/theme/app_icons.dart';
import '../../domain/entities/wallet_entity.dart';
import '../cubit/wallet_cubit.dart';
import '../cubit/wallet_state.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  @override
  void initState() {
    super.initState();
    context.read<WalletCubit>().loadWallets();
  }

  // =========================================================
  // DIALOG TAMBAH DAN EDIT DOMPET
  // =========================================================
  void _showWalletDialog({WalletEntity? wallet}) {
    final isEdit = wallet != null;
    final nameCtrl = TextEditingController(text: wallet?.name ?? '');
    final balanceCtrl = TextEditingController(
      text: wallet != null ? wallet.balance.toString() : '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        final isDark =
            Theme.of(dialogContext).brightness == Brightness.dark;

        final dialogBackground =
            isDark ? AppColors.surface : AppColors.lightBackgroundCard;
        final pageBackground =
            isDark ? AppColors.surface : AppColors.lightBackgroundCard;
        final primaryText =
            isDark ? AppColors.textPrimary : AppColors.primaryText;
        final secondaryText =
            isDark ? AppColors.textSecondary : AppColors.secondaryText;
        final borderColor =
            isDark ? AppColors.darkBorder : AppColors.lightBorder;

        return AlertDialog(
          backgroundColor: dialogBackground,
          surfaceTintColor: Colors.transparent,
          title: Text(
            isEdit ? 'Edit Dompet' : 'Tambah Dompet Baru',
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: TextStyle(color: primaryText),
                decoration: InputDecoration(
                  labelText: 'Nama Dompet',
                  labelStyle: TextStyle(color: secondaryText),
                  filled: true,
                  fillColor: pageBackground,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(
                      color: AppColors.accentBlue,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: balanceCtrl,
                keyboardType: TextInputType.number,
                enabled: !isEdit,
                style: TextStyle(color: primaryText),
                decoration: InputDecoration(
                  labelText:
                      isEdit ? 'Saldo saat ini (Rp)' : 'Saldo awal (Rp)',
                  helperText: isEdit
                      ? 'Saldo berubah melalui pencatatan transaksi.'
                      : null,
                  labelStyle: TextStyle(color: secondaryText),
                  helperStyle: TextStyle(color: secondaryText),
                  filled: true,
                  fillColor: pageBackground,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(
                      color: AppColors.accentBlue,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accentBlue,
              ),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal', style: TextStyle(color: AppColors.negative)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final balance =
                    int.tryParse(balanceCtrl.text.trim());

                if (nameCtrl.text.trim().isEmpty ||
                    balance == null ||
                    balance < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: isDark
                          ? AppColors.surface
                          : AppColors.navyBlue,
                      content: const Text(
                        'Masukkan nama dan saldo awal yang valid.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  );
                  return;
                }

                final walletData = WalletEntity(
                  id: isEdit
                      ? wallet.id
                      : DateTime.now()
                          .microsecondsSinceEpoch
                          .toString(),
                  name: nameCtrl.text.trim(),
                  balance: balance,
                  iconName:
                      wallet?.iconName ?? 'account_balance_wallet',
                );

                if (isEdit) {
                  context.read<WalletCubit>().update(walletData);
                } else {
                  context.read<WalletCubit>().add(walletData);
                }

                Navigator.pop(dialogContext);
              },
              child: Text(isEdit ? 'Simpan' : 'Tambah'),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // HALAMAN DOMPET
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    // Warna dinamis berdasarkan tema aktif.
    final pageBackground =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor =
        isDark ? AppColors.surface : AppColors.lightBackgroundCard;
    final primaryText =
        isDark ? AppColors.textPrimary : AppColors.primaryText;
    final secondaryText =
        isDark ? AppColors.textSecondary : AppColors.secondaryText;
    final borderColor =
        isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final accentColor =
        isDark ? AppColors.accentBlue : AppColors.navyBlue;

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        title: Text(
          'Dompet & Kas Mahasiswa',
          style: TextStyle(
            color: primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: surfaceColor,
        foregroundColor: primaryText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryText),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: borderColor,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'Tambah Dompet',
              icon: const Icon(Icons.add_card),
              onPressed: () => _showWalletDialog(),
            ),
          ),
        ],
      ),
      body: BlocBuilder<WalletCubit, WalletState>(
        builder: (context, state) {
          return switch (state) {
            WalletInitial() => Center(
                child: Text(
                  'Memuat Dompet...',
                  style: TextStyle(color: secondaryText),
                ),
              ),
            WalletLoading() => Center(
                child: CircularProgressIndicator(
                  color: accentColor,
                ),
              ),
            WalletError(:final message) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Galat: $message',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.negative),
                  ),
                ),
              ),
            WalletSuccess(:final wallets) => wallets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AppIcons.walletActive,
                          size: 48,
                          color: secondaryText,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Belum ada dompet.',
                          style: TextStyle(color: secondaryText),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _showWalletDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Tambah Dompet'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: wallets.length,
                    itemBuilder: (context, index) {
                      final item = wallets[index];

                      return Card(
                        color: surfaceColor,
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: borderColor,
                            width: 1,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: isDark
                                ? AppColors.darkNavigation
                                : AppColors.lightNavigation,
                            child: Icon(
                              AppIcons.walletActive,
                              color: AppColors.accentBlue,
                            ),
                          ),
                          title: Text(
                            item.name,
                            style: TextStyle(
                              color: primaryText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Saldo: ${CurrencyFormatter.format(item.balance)}',
                              style: TextStyle(
                                color: secondaryText,
                              ),
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit Dompet',
                                icon: const Icon(AppIcons.edit),
                                color: AppColors.accentBlue,
                                onPressed: () =>
                                    _showWalletDialog(wallet: item),
                              ),
                              IconButton(
                                tooltip: 'Hapus Dompet',
                                icon: const Icon(AppIcons.delete),
                                color: AppColors.negative,
                                onPressed: () => context
                                    .read<WalletCubit>()
                                    .delete(item.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          };
        },
      ),
    );
  }
}
