import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../cubit/transaction_cubit.dart';
import '../cubit/transaction_state.dart';

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
    // Memuat data pertama kali saat layar dibuka
    context.read<TransactionCubit>().loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    // Deteksi ukuran layar untuk tata letak adaptif (Modul 5)
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    // 5 Menu navigasi utama sesuai referensi desain
    final destinations = const [
      NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
      NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Wallet'),
      NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
      NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Report'),
      NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
    ];

    final railDestinations = destinations.map((d) =>
      NavigationRailDestination(icon: d.icon, label: Text(d.label))
    ).toList();

    // Konten utama yang dilindungi SafeArea (Modul 3)
    final content = SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('My Wallet 🔒', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(
                    'Rp 5.000.000', 
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold)
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text('Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                    // Menggunakan ListView.builder untuk hemat memori (Modul 3)
                    : ListView.builder(
                        itemCount: transactions.length,
                        itemBuilder: (context, index) {
                          final item = transactions[index];
                          return ListTile(
                            title: Row(
                              children: [
                                // Mencegah galat overflow teks panjang (Modul 3)
                                Expanded(
                                  child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis)
                                ),
                                Text('Rp ${item.amount}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                            subtitle: Text(item.date.toString().substring(0, 10)),
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

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/form'), // Navigasi GoRouter (Modul 4)
        child: const Icon(Icons.add),
      ),
      // Menerapkan tata letak responsif adaptif
      body: isMobile ? content : Row(
        children: [
          NavigationRail(
            selectedIndex: _navIndex,
            onDestinationSelected: (val) => setState(() => _navIndex = val),
            destinations: railDestinations,
          ),
          Expanded(child: content),
        ],
      ),
      bottomNavigationBar: isMobile ? NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (val) => setState(() => _navIndex = val),
        destinations: destinations,
      ) : null,
    );
  }
}