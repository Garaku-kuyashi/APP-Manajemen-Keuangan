import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

  void _showAddWalletDialog() {
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tambah Dompet Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Dompet',
                hintText: 'Misal: SeaBank / Kantong Dana',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: balanceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Saldo Awal (Rp)',
                hintText: 'Misal: 500000',
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
              if (nameCtrl.text.isNotEmpty && balanceCtrl.text.isNotEmpty) {
                final newWallet = WalletEntity(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameCtrl.text.trim(),
                  balance: int.tryParse(balanceCtrl.text.trim()) ?? 0,
                  iconName: 'account_balance_wallet',
                );
                context.read<WalletCubit>().add(newWallet);
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Simpan'),
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
            onPressed: _showAddWalletDialog,
          ),
        ],
      ),
      body: BlocBuilder<WalletCubit, WalletState>(
        builder: (context, state) {
          return switch (state) {
            WalletInitial() => const Center(child: Text('Memuat Dompet...')),
            WalletLoading() => const Center(child: CircularProgressIndicator.adaptive()),
            WalletError(:final message) => Center(child: Text('Galat: $message')),
            WalletSuccess(:final wallets) => wallets.isEmpty
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
                            child: Icon(Icons.account_balance_wallet),
                          ),
                          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Saldo: Rp ${item.balance}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: () => context.read<WalletCubit>().delete(item.id),
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