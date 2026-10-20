import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mymoney/core/di/theme/app_colors.dart';
import 'package:mymoney/core/utils/currency_formatter.dart';
import 'package:mymoney/core/utils/dashboard_calculator.dart';
import 'package:mymoney/core/utils/dashboard_date_formatter.dart';
import 'package:mymoney/features/chat/presentation/cubit/conversation_cubit.dart';
import 'package:mymoney/features/login/presentation/cubit/auth_cubit.dart';

import '../theme/dashboard_theme.dart';
import '../widgets/dashboard_shared_widgets.dart';

import '../../domain/entities/transaction_entity.dart';
import '../cubit/transaction_cubit.dart';
import '../cubit/transaction_state.dart';
import '../../../wallet/presentation/cubit/wallet_state.dart';
import '../../../search/presentation/pages/search_page.dart';
import '../../../wallet/presentation/pages/wallet_page.dart';
import '../../../report/presentation/pages/report_page.dart';
import '../../../chat/presentation/pages/chat_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../../wallet/presentation/cubit/wallet_cubit.dart';
import '../../../../core/di/theme/app_icons.dart';

// ---------------------------------------------------------------------------
// Index tab
// ---------------------------------------------------------------------------
class _Tab {
  static const home = 0;
  static const chat = 1;
  static const report = 2;
  static const profile = 3;
  static const wallet = 4;
}

class TransactionDashboard extends StatefulWidget {
  const TransactionDashboard({super.key});

  @override
  State<TransactionDashboard> createState() => _TransactionDashboardState();
}

class _TransactionDashboardState extends State<TransactionDashboard> {
  int _navIndex = _Tab.home;
  bool _hideBalance = false;
  final int _monthlyBudgetLimit = 1500000;

  @override
  void initState() {
    super.initState();
    unawaited(_loadInitialData());
  }

  Future<void> _loadInitialData() async {
    try {
      final sessionReady = await context
          .read<AuthCubit>()
          .ensureVerifiedSession();
      if (!mounted || !sessionReady) return;
    } catch (error) {
      debugPrint('Gagal menyegarkan sesi sebelum memuat dashboard: $error');
    }

    if (!mounted) return;
    await Future.wait([
      context.read<TransactionCubit>().loadTransactions(),
      context.read<WalletCubit>().loadWallets(),
    ]);
  }

  void _onNavigationSelected(int index) {
    // Reset status ketika meninggalkan tab AI Chat.
    if (_navIndex == _Tab.chat && index != _Tab.chat) {
      context.read<ConversationCubit>().resetConversation();
    }

    setState(() {
      _navIndex = index;
    });
  }

  void _goToWallet() => setState(() => _navIndex = _Tab.wallet);

  // =========================================================================
  // HEADER
  // =========================================================================
  Widget _buildHeader(DashboardColors colors, String username) {
    final photoBytes = context.watch<AuthCubit>().state?.profilePhotoBytes;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.accentBlue.withOpacity(
              colors.isDark ? 0.20 : 0.12,
            ),
            backgroundImage: photoBytes == null || photoBytes.isEmpty
                ? null
                : MemoryImage(photoBytes),
            child: photoBytes == null || photoBytes.isEmpty
                ? const Icon(AppIcons.profile, color: AppColors.accentBlue)
                : null,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi, $username',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DashboardDateFormatter.today(),
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // KARTU SALDO
  // =========================================================================
  Widget _buildBalanceCard({
    required int totalBalance,
    required int income,
    required int expense,
    required double? incomeChange,
    required double? expenseChange,
    required DashboardColors colors,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors.balanceGradient,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: CustomPaint(
          painter: CardStripePainter(),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Chip akun + titik tiga
                Row(
                  children: [
                    GestureDetector(
                      onTap: _goToWallet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 15,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Semua Dompet',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Sisa Uang Saku',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 4),

                // Total saldo + ikon mata
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _hideBalance
                              ? 'Rp ••••••'
                              : CurrencyFormatter.format(totalBalance),
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: totalBalance >= 0
                                ? Colors.white
                                : AppColors.negative,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () =>
                          setState(() => _hideBalance = !_hideBalance),
                      icon: Icon(
                        _hideBalance
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.white.withOpacity(0.15)),
                const SizedBox(height: 14),

                // Pemasukan & pengeluaran bulanan
                Row(
                  children: [
                    Expanded(
                      child: _buildMonthlyStat(
                        label: 'Pemasukan Bulanan',
                        amount: income,
                        colors: colors,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMonthlyStat(
                        label: 'Pengeluaran Bulanan',
                        amount: expense,
                        colors: colors,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyStat({
    required String label,
    required int amount,
    required DashboardColors colors,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.white60),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Text(
                _hideBalance ? 'Rp ••••••' : CurrencyFormatter.format(amount),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // KARTU ANGGARAN BULANAN
  // =========================================================================
  Widget _buildBudgetCard(int totalExpense, DashboardColors colors) {
    final ratio = (totalExpense / _monthlyBudgetLimit).clamp(0.0, 1.0);
    final percent = (totalExpense / _monthlyBudgetLimit * 100).round();
    final isOverBudget = totalExpense > _monthlyBudgetLimit;
    final barColor = isOverBudget ? AppColors.negative : AppColors.accentBlue;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isOverBudget
                ? '⚠️ Pengeluaran Melebihi Target!'
                : 'Anggaran Bulanan',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isOverBudget ? AppColors.negative : colors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              color: barColor,
              backgroundColor: colors.track,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                    children: [
                      const TextSpan(text: 'Terpakai '),
                      TextSpan(
                        text: CurrencyFormatter.format(totalExpense),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: colors.textPrimary,
                        ),
                      ),
                      TextSpan(
                        text:
                            ' / ${CurrencyFormatter.format(_monthlyBudgetLimit)}',
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: barColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // RIWAYAT TRANSAKSI
  // =========================================================================
  Widget _buildTransactionSliver(
    BuildContext context,
    TransactionState state,
    DashboardColors colors,
  ) {
    return switch (state) {
      DataInitial() => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('Menyiapkan Data...')),
        ),
      ),
      DataLoading() => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      ),
      DataError(:final message) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(child: Text('Galat: $message')),
        ),
      ),
      DataSuccess(:final transactions) =>
        transactions.isEmpty
            ? const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('Belum ada transaksi.')),
                ),
              )
            : SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: transactions.length > 10
                      ? 10
                      : transactions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = transactions[index];
                    final isIncome = item.type == TransactionType.income;
                    final accent = isIncome
                        ? AppColors.positive
                        : AppColors.negative;
                    final accentBg = accent.withOpacity(
                      colors.isDark ? 0.18 : 0.12,
                    );

                    return Container(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      decoration: BoxDecoration(
                        color: colors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: colors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: accentBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isIncome ? AppIcons.income : AppIcons.expense,
                              color: accent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 12,
                                      color: colors.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        '${DashboardDateFormatter.shortDate(item.date)} • ${item.category} • ${item.walletName}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${isIncome ? '+' : '-'} ${CurrencyFormatter.format(item.amount)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isIncome
                                  ? AppColors.positive
                                  : AppColors.negative,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
    };
  }

  // =========================================================================
  // KONTEN DASHBOARD
  // =========================================================================
  Widget _buildDashboard(
    BuildContext context,
    DashboardColors colors,
    String userName,
  ) {
    return Theme(
      data: dashboardThemeOf(context, colors),
      child: ColoredBox(
        color: colors.background,
        child: SafeArea(
          bottom: false,
          child: BlocBuilder<TransactionCubit, TransactionState>(
            builder: (context, state) {
              // Hitung pemasukan/pengeluaran bulan ini & bulan lalu
              final now = DateTime.now();
              final prev = DateTime(now.year, now.month - 1);
              int income = 0, expense = 0, prevIncome = 0, prevExpense = 0;

              if (state is DataSuccess) {
                for (final t in state.transactions) {
                  final isThisMonth =
                      t.date.year == now.year && t.date.month == now.month;
                  final isPrevMonth =
                      t.date.year == prev.year && t.date.month == prev.month;
                  final isIncome = t.type == TransactionType.income;

                  if (isThisMonth) {
                    if (isIncome) {
                      income += t.amount;
                    } else {
                      expense += t.amount;
                    }
                  } else if (isPrevMonth) {
                    if (isIncome) {
                      prevIncome += t.amount;
                    } else {
                      prevExpense += t.amount;
                    }
                  }
                }
              }

              // Sisa uang = total saldo semua dompet (sama dengan yang dilihat AI Chat)
              final walletState = context.watch<WalletCubit>().state;
              final int totalBalance = walletState is WalletSuccess
                  ? walletState.wallets.fold<int>(
                      0,
                      (sum, w) => sum + w.balance,
                    )
                  : 0;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(colors, userName)),
                  SliverToBoxAdapter(
                    child: _buildBalanceCard(
                      totalBalance: totalBalance,
                      income: income,
                      expense: expense,
                      incomeChange: DashboardCalculator.changePercentage(
                        income,
                        prevIncome,
                      ),
                      expenseChange: DashboardCalculator.changePercentage(
                        expense,
                        prevExpense,
                      ),
                      colors: colors,
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildBudgetCard(expense, colors)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Riwayat Transaksi',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SearchPage(),
                                ),
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: colors.isDark
                                  ? AppColors.accentBlue
                                  : AppColors.navyBlue,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Lihat Semua',
                              style: TextStyle(
                                color: AppColors.accentBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildTransactionSliver(context, state, colors),
                  const SliverToBoxAdapter(child: SizedBox(height: 96)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // BOTTOM BAR: Home | AI Chat | (+) | Report | Profile
  // =========================================================================
  Widget _buildBottomBar(DashboardColors colors) {
    return BottomAppBar(
      color: colors.navigationBar,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 72,
      padding: EdgeInsets.zero,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: Row(
        children: [
          Expanded(
            child: DashboardNavItem(
              icon: AppIcons.home,
              activeIcon: AppIcons.homeActive,
              label: 'Home',
              selected: _navIndex == _Tab.home,
              unselectedColor: colors.textSecondary,
              onTap: () => _onNavigationSelected(0),
            ),
          ),
          Expanded(
            child: DashboardNavItem(
              icon: AppIcons.ai,
              activeIcon: AppIcons.aiActive,
              label: 'AI Chat',
              selected: _navIndex == _Tab.chat,
              unselectedColor: colors.textSecondary,
              onTap: () => _onNavigationSelected(1),
            ),
          ),
          const SizedBox(width: 72), // ruang untuk tombol tambah
          Expanded(
            child: DashboardNavItem(
              icon: Icons.insert_chart_outlined_rounded,
              activeIcon: Icons.insert_chart_rounded,
              label: 'Report',
              selected: _navIndex == _Tab.report,
              unselectedColor: colors.textSecondary,
              onTap: () => _onNavigationSelected(2),
            ),
          ),
          Expanded(
            child: DashboardNavItem(
              icon: AppIcons.profile,
              activeIcon: AppIcons.profileActive,
              label: 'Profile',
              selected: _navIndex == _Tab.profile,
              unselectedColor: colors.textSecondary,
              onTap: () => _onNavigationSelected(3),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // BUILD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthCubit>().state;
    final userName = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!
        : 'Pengguna';

    final colors = DashboardColors.from(context);
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    final Widget activeBody = switch (_navIndex) {
      _Tab.chat => const ChatPage(),
      _Tab.report => const ReportPage(),
      _Tab.profile => const ProfilePage(),
      _Tab.wallet => const WalletPage(),
      _ => _buildDashboard(context, colors, userName),
    };

    // Urutan sesuai index _Tab (dipakai oleh NavigationRail di layar lebar)
    const railItems = [
      NavigationRailDestination(
        icon: Icon(AppIcons.home),
        selectedIcon: Icon(AppIcons.homeActive),
        label: Text('Home'),
      ),
      NavigationRailDestination(
        icon: Icon(AppIcons.ai),
        selectedIcon: Icon(AppIcons.aiActive),
        label: Text('AI Chat'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.insert_chart_outlined_rounded),
        selectedIcon: Icon(Icons.insert_chart_outlined_rounded),
        label: Text('Report'),
      ),
      NavigationRailDestination(
        icon: Icon(AppIcons.profile),
        selectedIcon: Icon(AppIcons.profileActive),
        label: Text('Profile'),
      ),
      NavigationRailDestination(
        icon: Icon(AppIcons.wallet),
        selectedIcon: Icon(AppIcons.walletActive),
        label: Text('Wallet'),
      ),
    ];

    return BlocBuilder<ConversationCubit, bool>(
      builder: (context, conversationStarted) {
        return PopScope(
          canPop: _navIndex == _Tab.home,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              if (_navIndex == _Tab.chat) {
                context.read<ConversationCubit>().resetConversation();
              }

              setState(() {
                _navIndex = _Tab.home;
              });
            }
          },
          child: Scaffold(
            backgroundColor: colors.background,
            extendBody: isMobile,

            floatingActionButtonLocation:
                FloatingActionButtonLocation.miniCenterDocked,

            floatingActionButton:
                (isMobile &&
                    !keyboardOpen &&
                    (_navIndex != _Tab.chat || !conversationStarted))
                ? FloatingActionButton(
                    onPressed: () => context.push('/form'),
                    backgroundColor: AppColors.accentBlue,
                    foregroundColor: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 0,
                    child: const Icon(AppIcons.add),
                  )
                : null,

            body: isMobile
                ? activeBody
                : Row(
                    children: [
                      NavigationRail(
                        backgroundColor: colors.background,
                        selectedIconTheme: const IconThemeData(
                          color: AppColors.accentBlue,
                        ),
                        unselectedIconTheme: IconThemeData(
                          color: colors.textSecondary,
                        ),
                        selectedLabelTextStyle: const TextStyle(
                          color: AppColors.accentBlue,
                        ),
                        unselectedLabelTextStyle: TextStyle(
                          color: colors.textSecondary,
                        ),
                        selectedIndex: _navIndex,
                        labelType: NavigationRailLabelType.all,
                        onDestinationSelected: _onNavigationSelected,

                        // FAB desktop tetap tampil.
                        leading: Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: FloatingActionButton(
                            backgroundColor: AppColors.accentBlue,
                            foregroundColor: Colors.white,
                            onPressed: () => context.push('/form'),
                            child: const Icon(AppIcons.add),
                          ),
                        ),
                        destinations: railItems,
                      ),
                      Expanded(child: activeBody),
                    ],
                  ),

            bottomNavigationBar: isMobile ? _buildBottomBar(colors) : null,
          ),
        );
      },
    );
  }
}
