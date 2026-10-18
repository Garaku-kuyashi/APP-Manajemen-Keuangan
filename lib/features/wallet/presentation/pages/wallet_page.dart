import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/ui/app_icons.dart';
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

  void _showWalletDialog({WalletEntity? wallet}) {
    final isEdit = wallet != null;
    final nameCtrl = TextEditingController(text: wallet?.name ?? '');
    final balanceCtrl = TextEditingController(
      text: wallet != null ? wallet.balance.toString() : '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEdit ? 'Edit Dompet' : 'Tambah Dompet Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nama Dompet'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: balanceCtrl,
              keyboardType: TextInputType.number,
              enabled: !isEdit,
              decoration: InputDecoration(
                labelText: isEdit ? 'Saldo saat ini (Rp)' : 'Saldo awal (Rp)',
                helperText: isEdit
                    ? 'Saldo berubah melalui pencatatan transaksi.'
                    : null,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              final balance = int.tryParse(balanceCtrl.text.trim());
              if (nameCtrl.text.trim().isEmpty ||
                  balance == null ||
                  balance < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Masukkan nama dan saldo awal yang valid.'),
                  ),
                );
                return;
              }

              final walletData = WalletEntity(
                id: isEdit
                    ? wallet.id
                    : DateTime.now().microsecondsSinceEpoch.toString(),
                name: nameCtrl.text.trim(),
                balance: balance,
                iconName: wallet?.iconName ?? 'account_balance_wallet',
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dompet & Kas Mahasiswa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_card),
            onPressed: () => _showWalletDialog(),
          ),
        ],
      ),
      body: BlocBuilder<WalletCubit, WalletState>(
        builder: (context, state) {
          return switch (state) {
            WalletInitial() => const Center(child: Text('Memuat Dompet...')),
            WalletLoading() => const Center(
              child: CircularProgressIndicator.adaptive(),
            ),
            WalletError(:final message) => Center(
              child: Text('Galat: $message'),
            ),
            WalletSuccess(:final wallets) =>
              wallets.isEmpty
                  ? const Center(child: Text('Belum ada dompet.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: wallets.length,
                      itemBuilder: (context, index) {
                        final item = wallets[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const CircleAvatar(
                              child: Icon(AppIcons.walletActive),
                            ),
                            title: Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text('Saldo: Rp ${item.balance}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    AppIcons.edit,
                                    color: Colors.blueAccent,
                                  ),
                                  onPressed: () =>
                                      _showWalletDialog(wallet: item),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    AppIcons.delete,
                                    color: Colors.redAccent,
                                  ),
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
