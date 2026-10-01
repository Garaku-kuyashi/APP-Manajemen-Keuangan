import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/theme/theme_cubit.dart';
import '../../../transaction/presentation/cubit/transaction_cubit.dart';
import '../../../transaction/presentation/cubit/transaction_state.dart';
import '../../../wallet/presentation/cubit/wallet_cubit.dart';
import '../../../wallet/presentation/cubit/wallet_state.dart';

class MorePage extends StatefulWidget {
  const MorePage({super.key});

  @override
  State<MorePage> createState() => _MorePageState();
}

class _MorePageState extends State<MorePage> {
  String _userName = "M. Fahrianor";
  String _userNim = "2209106000";
  int _userBudget = 1500000;

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: _userName);
    final nimCtrl = TextEditingController(text: _userNim);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profil Mahasiswa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nama Lengkap'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nimCtrl,
              decoration: const InputDecoration(labelText: 'NIM'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _userName = nameCtrl.text.trim();
                _userNim = nimCtrl.text.trim();
              });
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
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
                  SnackBar(content: Text('Batas anggaran berhasil diubah ke Rp $_userBudget')),
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
      final String csvData = "Tanggal,Judul,Kategori,Nominal,Tipe,Dompet\n" +
          state.transactions.map((tx) {
            return "${tx.date.toString().substring(0, 10)},\"${tx.title}\",${tx.category},${tx.amount},${tx.type.name},${tx.walletName}";
          }).join("\n");

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
              icon: const Icon(Icons.copy),
              label: const Text('Salin Data'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil & Pengaturan'),
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
                          Text(_userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(height: 2),
                          Text('NIM: $_userNim', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                          const SizedBox(height: 6),
                          Chip(
                            label: const Text('Mahasiswa Hemat 🛡️', style: TextStyle(fontSize: 10)),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
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
                              final count = state is DataSuccess ? state.transactions.length : 0;
                              return Text('$count', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
                            },
                          ),
                          const Text('Transaksi', style: TextStyle(fontSize: 11, color: Colors.grey)),
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
                              final count = state is WalletSuccess ? state.wallets.length : 0;
                              return Text('$count', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
                            },
                          ),
                          const Text('Dompet Kas', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
            const Text('Manajemen Keuangan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),

            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.track_changes, color: Colors.orangeAccent),
                    title: const Text('Atur Batas Anggaran Bulanan'),
                    subtitle: Text('Target: Rp $_userBudget / bulan'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showSetBudgetDialog,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.download_outlined, color: Colors.greenAccent),
                    title: const Text('Ekspor Laporan Transaksi'),
                    subtitle: const Text('Salin format CSV untuk LPJ'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showExportDialog(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            const Text('Pengaturan Sistem', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),

            Card(
              child: Column(
                children: [
                  // OPSI SAKELAR LIGHT / DARK MODE REAKTIF
                  BlocBuilder<ThemeCubit, ThemeMode>(
                    builder: (context, themeMode) {
                      final isDark = themeMode == ThemeMode.dark;
                      return ListTile(
                        leading: Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
                        title: const Text('Tema Tampilan'),
                        subtitle: Text(isDark ? 'Material 3 Dark Mode' : 'Material 3 Light Mode'),
                        trailing: Switch(
                          value: isDark,
                          onChanged: (val) {
                            context.read<ThemeCubit>().toggleTheme(val);
                          },
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Versi Aplikasi'),
                    subtitle: const Text('v1.0.0 • Clean Architecture (Feature-First)'),
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