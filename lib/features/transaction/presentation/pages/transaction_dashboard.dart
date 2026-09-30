import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/transaction_entity.dart';
import '../cubit/transaction_cubit.dart';
import '../cubit/transaction_state.dart';
import '../../../wallet/presentation/pages/wallet_page.dart';

class TransactionDashboard extends StatefulWidget {
  const TransactionDashboard({super.key});

  @override
  State<TransactionDashboard> createState() => _TransactionDashboardState();
}

class _TransactionDashboardState extends State<TransactionDashboard> {
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    // Memuat data transaksi saat pertama kali halaman dibuka
    context.read<TransactionCubit>().loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    // Deteksi ukuran layar untuk tata letak adaptif (Modul 5)
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    // Destinasi navigasi utama
    final destinations = const [
      NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
      NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Wallet'),
      NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
      NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Report'),
      NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
    ];

    final railDestinations = destinations
        .map((d) => NavigationRailDestination(icon: d.icon, label: Text(d.label)))
        .toList();

    // Konten Dashboard Transaksi
    final dashboardContent = SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kartu Saldo & Cashflow Mahasiswa
          BlocBuilder<TransactionCubit, TransactionState>(
            builder: (context, state) {
              int totalBalance = 0;
              int totalExpense = 0;

              if (state is DataSuccess) {
                for (var item in state.transactions) {
                  if (item.type == TransactionType.income) {
                    totalBalance += item.amount;
                  } else {
                    totalBalance -= item.amount;
                    totalExpense += item.amount;
                  }
                }
              }

              return Card(
                margin: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sisa Uang Saku 🔒', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        'Rp $totalBalance',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: totalBalance >= 0 ? Colors.greenAccent : Colors.redAccent,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.arrow_downward, color: Colors.redAccent, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Total Pengeluaran: Rp $totalExpense',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              'Riwayat Transaksi Mahasiswa',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: BlocBuilder<TransactionCubit, TransactionState>(
              builder: (context, state) {
                return switch (state) {
                  DataInitial() => const Center(child: Text('Menyiapkan Data...')),
                  DataLoading() => const Center(child: CircularProgressIndicator.adaptive()),
                  DataError(:final message) => Center(child: Text('Galat: $message')),
                  DataSuccess(:final transactions) => transactions.isEmpty
                      ? const Center(child: Text('Belum ada transaksi.'))
                      : ListView.builder(
                          itemCount: transactions.length,
                          itemBuilder: (context, index) {
                            final item = transactions[index];
                            final isIncome = item.type == TransactionType.income;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isIncome
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.red.withOpacity(0.2),
                                child: Icon(
                                  isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: isIncome ? Colors.green : Colors.red,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${isIncome ? '+' : '-'} Rp ${item.amount}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isIncome ? Colors.greenAccent : Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Row(
                                children: [
                                  Chip(
                                    label: Text(
                                      item.category,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                    padding: EdgeInsets.zero,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    item.date.toString().substring(0, 10),
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                onPressed: () => context.read<TransactionCubit>().delete(item.id),
                              ),
                            );
                          },
                        ),
                };
              },
            ),
          ),
        ],
      ),
    );

    // Bodi aktif berdasarkan tab yang dipilih
    final Widget activeBody = _navIndex == 1 ? const WalletPage() : dashboardContent;

    return Scaffold(
      floatingActionButton: _navIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/form'),
              icon: const Icon(Icons.add),
              label: const Text('Catat Transaksi'),
            )
          : null,
      body: isMobile
          ? activeBody
          : Row(
              children: [
                NavigationRail(
                  selectedIndex: _navIndex,
                  onDestinationSelected: (val) => setState(() => _navIndex = val),
                  destinations: railDestinations,
                ),
                Expanded(child: activeBody),
              ],
            ),
      bottomNavigationBar: isMobile
          ? NavigationBar(
              selectedIndex: _navIndex,
              onDestinationSelected: (val) => setState(() => _navIndex = val),
              destinations: destinations,
            )
          : null,
    );
  }
}