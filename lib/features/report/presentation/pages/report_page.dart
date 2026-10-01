import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../transaction/domain/entities/transaction_entity.dart';
import '../../../transaction/presentation/cubit/transaction_cubit.dart';
import '../../../transaction/presentation/cubit/transaction_state.dart';

class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Keuangan Mahasiswa'),
      ),
      body: BlocBuilder<TransactionCubit, TransactionState>(
        builder: (context, state) {
          if (state is DataLoading) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (state is DataError) {
            return Center(child: Text('Galat: ${state.message}'));
          }

          if (state is DataSuccess) {
            final transactions = state.transactions;

            if (transactions.isEmpty) {
              return const Center(child: Text('Belum ada data transaksi untuk dianalisis.'));
            }

            int totalIncome = 0;
            int totalExpense = 0;
            int totalSubscription = 0;
            Map<String, int> categoryExpenses = {};

            for (var tx in transactions) {
              if (tx.type == TransactionType.income) {
                totalIncome += tx.amount;
              } else {
                totalExpense += tx.amount;
                categoryExpenses[tx.category] = (categoryExpenses[tx.category] ?? 0) + tx.amount;

                // Hitung total beban subskripsi digital rutin
                if (tx.category == 'Langganan AI' ||
                    tx.category == 'Hiburan & Streaming' ||
                    tx.category == 'Kuota & Internet') {
                  totalSubscription += tx.amount;
                }
              }
            }

            final double expensePercentage = totalIncome > 0
                ? (totalExpense / totalIncome).clamp(0.0, 1.0)
                : 1.0;

            return SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // CARD 1: Analisis Pengeluaran & Rasio
                  Card(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Analisis Pengeluaran Bulanan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Pemasukan: Rp $totalIncome', style: const TextStyle(color: Colors.greenAccent)),
                              Text('Total Pengeluaran: Rp $totalExpense', style: const TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: expensePercentage,
                            minHeight: 10,
                            borderRadius: BorderRadius.circular(5),
                            color: expensePercentage > 0.8 ? Colors.redAccent : Colors.blueAccent,
                            backgroundColor: Colors.grey.shade800,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pengeluaran Anda mencapai ${(expensePercentage * 100).toStringAsFixed(1)}% dari pemasukan.',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // CARD 2: KARTU BEBAN SUBSKRIPSI RUTIN (NEW FEATURE)
                  Card(
                    color: Colors.purple.withOpacity(0.15),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Colors.purple,
                            child: Icon(Icons.subscriptions_outlined, color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Langganan Rutin Digital', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(
                                  'Rp $totalSubscription / bulan',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                                ),
                                const SizedBox(height: 2),
                                const Text('(AI, Streaming, Kuota & Internet)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text('Breakdown Per Kategori', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),

                  // CARD 3: Breakdown Per Kategori
                  if (categoryExpenses.isEmpty)
                    const Text('Belum ada pengeluaran yang dicatat.', style: TextStyle(color: Colors.grey))
                  else
                    ...categoryExpenses.entries.map((entry) {
                      final categoryPercentage = totalExpense > 0 ? (entry.value / totalExpense * 100) : 0.0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text('${categoryPercentage.toStringAsFixed(0)}%'),
                          ),
                          title: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Total: Rp ${entry.value}'),
                        ),
                      );
                    }),

                  const SizedBox(height: 16),

                  // CARD 4: Tips Finansial
                  Card(
                    color: expensePercentage > 0.8
                        ? Colors.red.withOpacity(0.15)
                        : Colors.green.withOpacity(0.15),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(
                            expensePercentage > 0.8 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                            color: expensePercentage > 0.8 ? Colors.redAccent : Colors.greenAccent,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              expensePercentage > 0.8
                                  ? 'Perhatian: Pengeluaran hampir menghabiskan uang saku Anda. Cek kembali langganan AI & Streaming yang tidak terlalu sering dipakai!'
                                  : 'Keuangan Anda aman! Alokasi sisa uang saku bisa dipindahkan ke Tabungan di menu Wallet.',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}