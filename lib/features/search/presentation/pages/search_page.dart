import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/theme/app_colors.dart';
import '../../../../core/di/theme/app_icons.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../transaction/domain/entities/transaction_entity.dart';
import '../../../transaction/presentation/cubit/transaction_cubit.dart';
import '../../../transaction/presentation/cubit/transaction_state.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final pageBackground =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor =
        isDark ? AppColors.surface : AppColors.lightBackgroundCard;
    final inputColor =
        isDark ? AppColors.background : AppColors.lightInputBackground;
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
          'Cari Transaksi',
          style: TextStyle(
            color: primaryText,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: surfaceColor,
        foregroundColor: primaryText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: borderColor),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(color: primaryText),
                cursorColor: accentColor,
                decoration: InputDecoration(
                  labelText: 'Pencarian',
                  hintText: 'Cari transaksi: ChatGPT, Kopi, Spotify...',
                  labelStyle: TextStyle(color: secondaryText),
                  hintStyle: TextStyle(color: secondaryText),
                  prefixIcon: Icon(Icons.search, color: accentColor),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          tooltip: 'Hapus pencarian',
                          icon: Icon(Icons.clear, color: secondaryText),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: inputColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: accentColor, width: 1.5),
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _query = value.trim().toLowerCase();
                  });
                },
              ),
            ),
            Expanded(
              child: BlocBuilder<TransactionCubit, TransactionState>(
                builder: (context, state) {
                  if (state is DataInitial || state is DataLoading) {
                    return Center(
                      child: CircularProgressIndicator(color: accentColor),
                    );
                  }

                  if (state is DataError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Galat: ${state.message}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.negative),
                        ),
                      ),
                    );
                  }

                  if (state is DataSuccess) {
                    final filtered = state.transactions.where((tx) {
                      final titleMatch =
                          tx.title.toLowerCase().contains(_query);
                      final categoryMatch =
                          tx.category.toLowerCase().contains(_query);
                      final walletMatch =
                          tx.walletName.toLowerCase().contains(_query);
                      return titleMatch || categoryMatch || walletMatch;
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 44,
                                color: secondaryText,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Tidak ada transaksi yang cocok dengan pencarian.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: secondaryText),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final isIncome = item.type == TransactionType.income;
                        final statusColor = isIncome
                            ? AppColors.positive
                            : AppColors.negative;

                        return Container(
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            leading: CircleAvatar(
                              backgroundColor:
                                  statusColor.withOpacity(isDark ? 0.18 : 0.12),
                              child: Icon(
                                isIncome ? AppIcons.income : AppIcons.expense,
                                color: statusColor,
                              ),
                            ),
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: primaryText,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '${item.category} • ${item.walletName}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: secondaryText),
                              ),
                            ),
                            trailing: Text(
                              '${isIncome ? '+' : '-'} ${CurrencyFormatter.format(item.amount)}',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
