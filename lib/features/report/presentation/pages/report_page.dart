import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mymoney/core/di/theme/app_colors.dart';
import 'package:mymoney/core/utils/currency_formatter.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBackground = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final navigationColor = isDark
        ? AppColors.surface
        : AppColors.lightBackgroundCard;
    final surfaceColor = isDark
        ? AppColors.surface
        : AppColors.lightBackgroundCard;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.primaryText;
    final secondaryText = isDark
        ? AppColors.textSecondary
        : AppColors.secondaryText;
    final dividerColor = isDark
        ? AppColors.divider
        : AppColors.lightInputBackground;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        title: const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text('Laporan & Survival Mode'),
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
      ),
      body: BlocBuilder<TransactionCubit, TransactionState>(
        builder: (context, txState) {
          if (txState is DataLoading) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (txState is DataError) {
            return Center(
              child: Text(
                'Galat: ${txState.message}',
                style: TextStyle(color: AppColors.negative),
              ),
            );
          }

          if (txState is DataSuccess) {
            final transactions = txState.transactions;

            if (transactions.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Belum ada data transaksi untuk dianalisis.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: secondaryText),
                  ),
                ),
              );
            }

            // Hitung akumulasi pemasukan, pengeluaran, dan langganan.
            int totalIncome = 0;
            int totalExpense = 0;
            int totalSubscription = 0;
            final Map<String, int> categoryExpenses = {};

            for (final tx in transactions) {
              if (tx.type == TransactionType.income) {
                totalIncome += tx.amount;
              } else {
                totalExpense += tx.amount;
                categoryExpenses[tx.category] =
                    (categoryExpenses[tx.category] ?? 0) + tx.amount;

                // Kategori yang dihitung sebagai subskripsi digital rutin.
                if (tx.category == 'Langganan AI' ||
                    tx.category == 'Hiburan & Streaming' ||
                    tx.category == 'Kuota & Internet') {
                  totalSubscription += tx.amount;
                }
              }
            }

            // Hitung jumlah hari sampai akhir bulan, termasuk hari ini.
            final now = DateTime.now();
            final lastDayOfMonth = DateTime(now.year, now.month + 1, 0).day;
            final remainingDays = (lastDayOfMonth - now.day) + 1;

            return BlocBuilder<WalletCubit, WalletState>(
              builder: (context, walletState) {
                int totalWalletBalance = 0;
                if (walletState is WalletSuccess) {
                  for (final wallet in walletState.wallets) {
                    totalWalletBalance += wallet.balance;
                  }
                }

                // Kalkulasi Survival Mode.
                final dailySafeBudget = remainingDays > 0
                    ? (totalWalletBalance / remainingDays).round()
                    : 0;
                final averageDailyExpense = totalExpense > 0
                    ? (totalExpense / 15).round()
                    : 0;
                final estimatedSurvivalDays = averageDailyExpense > 0
                    ? (totalWalletBalance / averageDailyExpense).round()
                    : 99;
                final isCritical = estimatedSurvivalDays < remainingDays;
                final statusColor = isCritical
                    ? AppColors.negative
                    : AppColors.positive;

                return SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      // Kartu 1: Prediksi Survival Mode.
                      Card(
                        elevation: 0,
                        color: surfaceColor,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: isCritical
                                ? AppColors.negative
                                : borderColor,
                            width: isCritical ? 1.2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isCritical
                                        ? Icons.warning_amber_rounded
                                        : Icons.shield_outlined,
                                    color: statusColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isCritical
                                          ? 'MODE TANGGAL TUA (KRITIS)'
                                          : 'PREDIKSI SURVIVAL MODE',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: statusColor,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Divider(height: 20, color: dividerColor),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Batas Jajan Hari Ini',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: secondaryText,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${CurrencyFormatter.format(dailySafeBudget)} / hari',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: primaryText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Estimasi Bertahan',
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: secondaryText,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '$estimatedSurvivalDays Hari Lagi',
                                          textAlign: TextAlign.end,
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: statusColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isCritical
                                    ? 'Uang saku Anda berisiko habis sebelum akhir bulan! Batasi pengeluaran maksimal ${CurrencyFormatter.format(dailySafeBudget)} per hari.'
                                    : 'Keuangan Anda terkendali. Sisa hari bulan ini adalah $remainingDays hari lagi.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Kartu 2: Gemini AI Advisor.
                      FutureBuilder<String>(
                        future: GeminiAiService.generateFinancialAdvice(
                          transactions,
                          currentBalance: totalWalletBalance,
                          dailySafeBudget: dailySafeBudget,
                          estimatedSurvivalDays: estimatedSurvivalDays,
                          remainingDays: remainingDays,
                          isCritical: isCritical,
                        ),
                        builder: (context, snapshot) {
                          final insightText =
                              snapshot.connectionState ==
                                  ConnectionState.waiting
                              ? 'Gemini AI sedang menganalisis pola keuanganmu...'
                              : (snapshot.data ?? 'Tidak ada saran.');

                          return Card(
                            elevation: 0,
                            color: surfaceColor,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: borderColor),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppColors.accentBlue,
                                    child: const Icon(
                                      Icons.psychology,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Gemini Financial Advisor',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.accentBlue,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          insightText,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: primaryText,
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

                      // Kartu 3: Beban subskripsi digital.
                      Card(
                        elevation: 0,
                        color: surfaceColor,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: borderColor),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppColors.accentBlue,
                                child: const Icon(
                                  Icons.subscriptions_outlined,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Langganan Rutin Digital',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: primaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${CurrencyFormatter.format(totalSubscription)} / bulan',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.accentBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '(AI, Streaming, Kuota & Internet)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      Text(
                        'Breakdown Per Kategori',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Kartu 4: Rincian pengeluaran per kategori.
                      if (categoryExpenses.isEmpty)
                        Text(
                          'Belum ada pengeluaran yang dicatat.',
                          style: TextStyle(color: secondaryText),
                        )
                      else
                        ...categoryExpenses.entries.map((entry) {
                          final categoryPercentage = totalExpense > 0
                              ? (entry.value / totalExpense * 100)
                              : 0.0;

                          return Card(
                            elevation: 0,
                            color: surfaceColor,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: borderColor),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.accentBlue,
                                child: Text(
                                  '${categoryPercentage.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              title: Text(
                                entry.key,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: primaryText,
                                ),
                              ),
                              subtitle: Text(
                                'Total: ${CurrencyFormatter.format(entry.value)}',
                                style: TextStyle(color: secondaryText),
                              ),
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
