import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../transaction/domain/entities/transaction_entity.dart';
import '../../../transaction/presentation/cubit/transaction_cubit.dart';
import '../../../transaction/presentation/cubit/transaction_state.dart';

class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final incomeColor = isDark ? Colors.greenAccent : Colors.green.shade800;
    final expenseColor = isDark ? Colors.redAccent : Colors.red.shade700;
    final barColor = isDark ? Colors.blueAccent : Colors.blue.shade700;
    final subsColor = isDark ? Colors.purpleAccent : Colors.purple.shade700;
    final mutedText = cs.onSurfaceVariant;

    Color tint(Color base) =>
        Color.alphaBlend(base.withOpacity(isDark ? 0.18 : 0.12), cs.surface);

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
              return const Center(
                  child: Text('Belum ada data transaksi untuk dianalisis.'));
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
                categoryExpenses[tx.category] =
                    (categoryExpenses[tx.category] ?? 0) + tx.amount;

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
            final bool isWarning = expensePercentage > 0.8;

            return SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // CARD 1: Analisis Pengeluaran & Rasio
                  Card(
                    color: cs.surfaceContainerHighest,
                    surfaceTintColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Analisis Pengeluaran Bulanan',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total Pemasukan: Rp $totalIncome',
                                  style: TextStyle(
                                      color: incomeColor,
                                      fontWeight: FontWeight.w600)),
                              Text('Total Pengeluaran: Rp $totalExpense',
                                  style: TextStyle(
                                      color: expenseColor,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: expensePercentage,
                            minHeight: 10,
                            borderRadius: BorderRadius.circular(5),
                            color: isWarning ? expenseColor : barColor,
                            backgroundColor: cs.outlineVariant,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pengeluaran Anda mencapai ${(expensePercentage * 100).toStringAsFixed(1)}% dari pemasukan.',
                            style: TextStyle(fontSize: 12, color: mutedText),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // CARD 2: Beban Subskripsi Rutin
                  Card(
                    color: tint(Colors.purple),
                    surfaceTintColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: Colors.purple,
                            child: Icon(Icons.subscriptions_outlined,
                                color: Colors.white),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Langganan Rutin Digital',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(
                                  'Rp $totalSubscription / bulan',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: subsColor),
                                ),
                                const SizedBox(height: 2),
                                Text('(AI, Streaming, Kuota & Internet)',
                                    style: TextStyle(
                                        fontSize: 11, color: mutedText)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  const Text('Breakdown Per Kategori',
                      style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 8),

                  // CARD 3: Breakdown Per Kategori
                  if (categoryExpenses.isEmpty)
                    Text('Belum ada pengeluaran yang dicatat.',
                        style: TextStyle(color: mutedText))
                  else
                    ...categoryExpenses.entries.map((entry) {
                      final categoryPercentage = totalExpense > 0
                          ? (entry.value / totalExpense * 100)
                          : 0.0;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: cs.primaryContainer,
                            foregroundColor: cs.onPrimaryContainer,
                            child: Text(
                                '${categoryPercentage.toStringAsFixed(0)}%'),
                          ),
                          title: Text(entry.key,
                              style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Total: Rp ${entry.value}'),
                        ),
                      );
                    }),

                  const SizedBox(height: 16),

                  // CARD 4: Tips Finansial
                  Card(
                    color: tint(isWarning ? Colors.red : Colors.green),
                    surfaceTintColor: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(
                            isWarning
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline,
                            color: isWarning ? expenseColor : incomeColor,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isWarning
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