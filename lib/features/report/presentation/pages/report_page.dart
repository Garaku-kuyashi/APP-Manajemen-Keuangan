import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/gemini_ai_service.dart';
import '../../../transaction/domain/entities/transaction_entity.dart';
import '../../../transaction/presentation/cubit/transaction_cubit.dart';
import '../../../transaction/presentation/cubit/transaction_state.dart';
import '../../../wallet/presentation/cubit/wallet_cubit.dart';
import '../../../wallet/presentation/cubit/wallet_state.dart';

class ReportPage extends StatelessWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan & Survival Mode'),
      ),
      body: BlocBuilder<TransactionCubit, TransactionState>(
        builder: (context, txState) {
          if (txState is DataLoading) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (txState is DataError) {
            return Center(child: Text('Galat: ${txState.message}'));
          }

          if (txState is DataSuccess) {
            final transactions = txState.transactions;

            if (transactions.isEmpty) {
              return const Center(
                child: Text('Belum ada data transaksi untuk dianalisis.'),
              );
            }

            // Hitung Akumulasi Pemasukan & Pengeluaran
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

                // Subskripsi Digital Rutin
                if (tx.category == 'Langganan AI' ||
                    tx.category == 'Hiburan & Streaming' ||
                    tx.category == 'Kuota & Internet') {
                  totalSubscription += tx.amount;
                }
              }
            }

            // Hitung Hari Bertahan Hidup
            final now = DateTime.now();
            final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
            final remainingDays = (lastDayOfMonth - now.day) + 1;

            return BlocBuilder<WalletCubit, WalletState>(
              builder: (context, walletState) {
                int totalWalletBalance = 0;
                if (walletState is WalletSuccess) {
                  for (var w in walletState.wallets) {
                    totalWalletBalance += w.balance;
                  }
                }

                // Kalkulasi Survival Mode
                final dailySafeBudget = remainingDays > 0
                    ? (totalWalletBalance / remainingDays).round()
                    : 0;
                final averageDailyExpense =
                    totalExpense > 0 ? (totalExpense / 15).round() : 0;
                final estimatedSurvivalDays = averageDailyExpense > 0
                    ? (totalWalletBalance / averageDailyExpense).round()
                    : 99;

                final isCritical = estimatedSurvivalDays < remainingDays;

                return SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      // === CARD 1: PREDIKSI SURVIVAL MODE ===
                      Card(
                        elevation: 3,
                        color: isCritical
                            ? Colors.red.shade900.withOpacity(0.3)
                            : Colors.teal.shade900.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: isCritical ? Colors.redAccent : Colors.tealAccent,
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isCritical
                                        ? Icons.warning_amber_rounded
                                        : Icons.shield_outlined,
                                    color: isCritical ? Colors.redAccent : Colors.tealAccent,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isCritical
                                        ? 'MODE TANGGAL TUA (KRITIS)'
                                        : 'PREDIKSI SURVIVAL MODE',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isCritical ? Colors.redAccent : Colors.tealAccent,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Batas Jajan Hari Ini',
                                        style: TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Rp $dailySafeBudget / hari',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'Estimasi Bertahan',
                                        style: TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$estimatedSurvivalDays Hari Lagi',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: isCritical
                                              ? Colors.redAccent
                                              : Colors.greenAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isCritical
                                    ? '⚠️ Uang saku Anda berisiko habis sebelum akhir bulan! Batasi pengeluaran maksimal Rp $dailySafeBudget per hari.'
                                    : '✅ Keuangan Anda terkendali. Sisa hari bulan ini adalah $remainingDays hari lagi.',
                                style: const TextStyle(fontSize: 12, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // === CARD 2: GEMINI AI ADVISOR (REALTIME) ===
                      FutureBuilder<String>(
                        future: GeminiAiService.generateFinancialAdvice(transactions),
                        builder: (context, snapshot) {
                          final insightText =
                              snapshot.connectionState == ConnectionState.waiting
                                  ? "🤖 Gemini AI sedang menganalisis pola keuanganmu..."
                                  : (snapshot.data ?? "Tidak ada saran.");

                          return Card(
                            color: Colors.indigo.shade900.withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              side: const BorderSide(color: Colors.indigoAccent),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: Colors.indigoAccent,
                                    child: Icon(Icons.psychology, color: Colors.white),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Gemini Financial Advisor',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.indigoAccent,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          insightText,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // === CARD 3: BEBAN SUBSKRIPSI DIGITAL ===
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
                                    const Text(
                                      'Total Langganan Rutin Digital',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Rp $totalSubscription / bulan',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.purpleAccent,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      '(AI, Streaming, Kuota & Internet)',
                                      style: TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      const Text(
                        'Breakdown Per Kategori',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 8),

                      // === CARD 4: BREAKDOWN KATEGORI ===
                      if (categoryExpenses.isEmpty)
                        const Text(
                          'Belum ada pengeluaran yang dicatat.',
                          style: TextStyle(color: Colors.grey),
                        )
                      else
                        ...categoryExpenses.entries.map((entry) {
                          final categoryPercentage =
                              totalExpense > 0 ? (entry.value / totalExpense * 100) : 0.0;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text('${categoryPercentage.toStringAsFixed(0)}%'),
                              ),
                              title: Text(
                                entry.key,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text('Total: Rp ${entry.value}'),
                            ),
                          );
                        }),
                    ],
                  ),
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}