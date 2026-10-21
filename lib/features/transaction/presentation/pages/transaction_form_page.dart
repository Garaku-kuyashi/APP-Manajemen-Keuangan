import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mymoney/core/di/theme/app_colors.dart';
import 'package:mymoney/core/utils/text_input_formatter.dart';

import '../../../../core/services/gemini_ai_service.dart';
import '../../../../core/di/theme/app_icons.dart';
import '../../../../core/utils/wallet_matcher.dart';
import '../../../wallet/domain/entities/wallet_entity.dart';
import '../../../wallet/presentation/cubit/wallet_cubit.dart';
import '../../../wallet/presentation/cubit/wallet_state.dart';
import '../../domain/entities/transaction_entity.dart';
import '../../domain/usecases/transaction_balance_rules.dart';
import '../cubit/transaction_cubit.dart';
import '../cubit/transaction_state.dart';

class TransactionFormPage extends StatefulWidget {
  final TransactionEntity? initialTransaction;

  const TransactionFormPage({super.key, this.initialTransaction});

  @override
  State<TransactionFormPage> createState() => _TransactionFormPageState();
}

class _TransactionFormPageState extends State<TransactionFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;

  TransactionType _selectedType = TransactionType.expense;
  String _selectedCategory = 'Makan & Kopi';
  WalletEntity? _selectedWallet;

  final List<String> _categories = [
    'Makan & Kopi',
    'Langganan AI',
    'Hiburan & Streaming',
    'Kuota & Internet',
    'Kebutuhan Kuliah',
    'Uang Saku',
    'Lainnya',
  ];

  bool get _isEditMode => widget.initialTransaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.initialTransaction;
    _titleCtrl = TextEditingController(text: tx?.title ?? '');
    _amountCtrl = TextEditingController(
      text: tx != null ? tx.amount.toString() : '',
    );

    if (tx != null) {
      _selectedType = tx.type;
      _selectedCategory = tx.category;
    }

    context.read<WalletCubit>().loadWallets();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _showAiPromptDialog() {
    final promptCtrl = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
          final dialogBackground = isDark
              ? AppColors.surface
              : AppColors.lightBackgroundCard;
          final primaryText = isDark
              ? AppColors.textPrimary
              : AppColors.primaryText;
          final secondaryText = isDark
              ? AppColors.textSecondary
              : AppColors.secondaryText;
          final inputBackground = isDark
              ? AppColors.surface
              : AppColors.lightBackgroundCard;
          final borderColor = isDark
              ? AppColors.darkBorder
              : AppColors.lightBorder;

          return AlertDialog(
            backgroundColor: dialogBackground,
            title: Row(
              children: [
                const Icon(AppIcons.aiActive, color: AppColors.accentBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gemini AI Express Input',
                    style: TextStyle(color: primaryText),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: promptCtrl,
                  enabled: !isLoading,
                  style: TextStyle(color: primaryText),
                  decoration: InputDecoration(
                    hintText: 'Bebas, misal: kopi 18rb pakai gopay / gajian 2jt masuk bca',
                    hintStyle: TextStyle(color: secondaryText),
                    filled: true,
                    fillColor: inputBackground,
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
                      borderSide: const BorderSide(
                        color: AppColors.accentBlue,
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
                if (isLoading) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(color: AppColors.accentBlue),
                  const SizedBox(height: 8),
                  Text(
                    'Gemini sedang menganalisis & menyimpan...',
                    style: TextStyle(fontSize: 12, color: secondaryText),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              FilledButton.icon(
                icon: const Icon(AppIcons.aiActive),
                label: const Text('Proses & Simpan'),
                onPressed: isLoading
                    ? null
                    : () async {
                        final textPrompt = promptCtrl.text.trim();
                        if (textPrompt.isEmpty) return;
                        final navigator = Navigator.of(ctx);
                        final messenger = ScaffoldMessenger.of(this.context);
                        setDialogState(() => isLoading = true);

                        final walletState = context.read<WalletCubit>().state;
                        final names = walletState is WalletSuccess
                            ? walletState.wallets.map((w) => w.name).toList()
                            : const <String>[];

                        final result =
                            await GeminiAiService.parseTransactionPrompt(
                              textPrompt,
                              walletNames: names,
                            );

                        if (!mounted) return;
                        setDialogState(() => isLoading = false);
                        navigator.pop();

                        if (result == null) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Aku belum nemu nominalnya. Coba tulis harganya ya, misal "kopi 18rb pakai gopay".',
                              ),
                              backgroundColor: AppColors.negative,
                            ),
                          );
                          return;
                        }
                        await _saveAiResult(result, textPrompt);
                      },
              ),
            ],
          );
        },
      ),
    ).whenComplete(promptCtrl.dispose);
  }

  /// Saves the parsed transaction using one of the user's existing wallets.
  Future<void> _saveAiResult(Map<String, dynamic> result, String prompt) async {
    final walletCubit = context.read<WalletCubit>();
    final txCubit = context.read<TransactionCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final walletState = walletCubit.state;
    if (walletState is! WalletSuccess || walletState.wallets.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Data dompet belum siap, coba lagi.'),
          backgroundColor: AppColors.accentBlue,
        ),
      );
      return;
    }
    final wallets = walletState.wallets;

    final matched =
        WalletMatcher.find(result['wallet'] as String?, wallets) ??
        WalletMatcher.find(prompt, wallets);
    final wallet = matched ?? WalletMatcher.fallback(wallets);

    final amount = result['amount'] as int;
    final title = result['title'] as String;
    final category = result['category'] as String;
    final isIncome = result['type'] == 'income';

    final balanceError = TransactionBalanceRules.validateAmount(
      amount: amount,
      type: isIncome ? TransactionType.income : TransactionType.expense,
      availableBalance: wallet.balance,
    );
    if (balanceError != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(balanceError),
          backgroundColor: AppColors.negative,
        ),
      );
      return;
    }

    final saved = await txCubit.add(
      TransactionEntity(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        amount: amount,
        date: DateTime.now(),
        category: category,
        type: isIncome ? TransactionType.income : TransactionType.expense,
        walletId: wallet.id,
        walletName: wallet.name,
      ),
    );
    if (!saved) return;
    await walletCubit.loadWallets();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      if (_selectedWallet == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pilih sumber dompet terlebih dahulu!'),
            backgroundColor: AppColors.accentBlue,
          ),
        );
        return;
      }

      final amount = int.parse(_amountCtrl.text.trim());
      final existing = widget.initialTransaction;
      final availableBalance = TransactionBalanceRules.availableBalance(
        currentBalance: _selectedWallet!.balance,
        walletId: _selectedWallet!.id,
        existingTransaction: existing,
      );
      final balanceError = TransactionBalanceRules.validateAmount(
        amount: amount,
        type: _selectedType,
        availableBalance: availableBalance,
      );
      if (balanceError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(balanceError),
            backgroundColor: AppColors.negative,
          ),
        );
        return;
      }

      final txData = TransactionEntity(
        id: _isEditMode
            ? widget.initialTransaction!.id
            : DateTime.now().microsecondsSinceEpoch.toString(),
        title: _titleCtrl.text.trim(),
        amount: amount,
        date: _isEditMode ? widget.initialTransaction!.date : DateTime.now(),
        category: _selectedCategory,
        type: _selectedType,
        walletId: _selectedWallet!.id,
        walletName: _selectedWallet!.name,
      );

      final walletCubit = context.read<WalletCubit>();
      final txCubit = context.read<TransactionCubit>();
      final saved = _isEditMode
          ? await txCubit.update(txData)
          : await txCubit.add(txData);
      if (saved) await walletCubit.loadWallets();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBackground = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final navigationColor = isDark
        ? AppColors.surface
        : AppColors.lightBackgroundCard;
    final cardColor = isDark
        ? AppColors.surface
        : AppColors.lightBackgroundCard;
    final inputBackground = isDark
        ? AppColors.background
        : AppColors.lightInputBackground;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.primaryText;
    final secondaryText = isDark
        ? AppColors.textSecondary
        : AppColors.secondaryText;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    InputDecoration fieldDecoration({
      required String labelText,
      String? hintText,
    }) {
      return InputDecoration(
        labelText: labelText,
        hintText: hintText,
        labelStyle: TextStyle(color: secondaryText),
        hintStyle: TextStyle(color: secondaryText),
        fillColor: inputBackground,
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
          borderSide: const BorderSide(color: AppColors.accentBlue, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.negative),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.negative, width: 1.2),
        ),
      );
    }

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text(
            _isEditMode ? 'Edit Transaksi' : 'Catat Keuangan Mahasiswa',
            style: TextStyle(color: primaryText),
          ),
        ),
        backgroundColor: navigationColor,
        foregroundColor: primaryText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: borderColor),
        ),
      ),
      body: BlocListener<TransactionCubit, TransactionState>(
        listener: (context, state) {
          if (state is DataSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _isEditMode
                      ? 'Transaksi berhasil diperbarui!'
                      : 'Transaksi berhasil dicatat!',
                ),
                backgroundColor: AppColors.positive,
              ),
            );
            context.pop();
          } else if (state is DataError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.negative,
              ),
            );
          }
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_isEditMode) ...[
                    OutlinedButton.icon(
                      onPressed: _showAiPromptDialog,
                      icon: const Icon(
                        AppIcons.aiActive,
                        color: AppColors.accentBlue,
                      ),
                      label: const Text(
                        'Isi & Simpan Otomatis Pakai Gemini AI 🪄',
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        foregroundColor: AppColors.accentBlue,
                        side: const BorderSide(color: AppColors.accentBlue),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  SegmentedButton<TransactionType>(
                    segments: [
                      ButtonSegment(
                        value: TransactionType.expense,
                        label: Text('Pengeluaran', style: TextStyle(color: primaryText)),
                        icon: Icon(AppIcons.expense, color: AppColors.negative),
                      ),
                      ButtonSegment(
                        value: TransactionType.income,
                        label: Text('Pemasukan', style: TextStyle(color: primaryText),),
                        icon: Icon(AppIcons.income, color: AppColors.positive),
                      ),
                    ],
                    selected: {_selectedType},
                    style: ButtonStyle(
                      foregroundColor: WidgetStatePropertyAll(primaryText),
                      backgroundColor: WidgetStateProperty.resolveWith((
                        states,
                      ) {
                        if (states.contains(WidgetState.selected)) {
                          return isDark ? AppColors.accentBlue : AppColors.lightInputBackground;
                        }
                        return cardColor;
                      }),
                      side: WidgetStatePropertyAll(
                        BorderSide(color: borderColor),
                      ),
                    ),
                    onSelectionChanged: (Set<TransactionType> newSelection) {
                      setState(() {
                        _selectedType = newSelection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _titleCtrl,
                    style: TextStyle(color: primaryText),
                    decoration: fieldDecoration(
                      labelText: 'Nama Transaksi',
                      hintText: 'Misal: ChatGPT Plus / Kopi Kenangan',
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Nama transaksi wajib diisi!'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    maxLength: 14,
                    inputFormatters: [RupiahInputFormatter()],
                    controller: _amountCtrl,
                    style: TextStyle(color: primaryText),
                    decoration: fieldDecoration(
                      labelText: 'Nominal (Rp)',
                      hintText: 'Misal: 50.000',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Nominal wajib diisi!';
                      }
                      final amount = int.tryParse(val.trim());
                      if (amount == null) return 'Harus berupa angka valid!';
                      final wallet = _selectedWallet;
                      if (wallet != null) {
                        final balance =
                            TransactionBalanceRules.availableBalance(
                              currentBalance: wallet.balance,
                              walletId: wallet.id,
                              existingTransaction: widget.initialTransaction,
                            );
                        return TransactionBalanceRules.validateAmount(
                          amount: amount,
                          type: _selectedType,
                          availableBalance: balance,
                        );
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    style: TextStyle(color: primaryText),
                    dropdownColor: cardColor,
                    decoration: fieldDecoration(labelText: 'Kategori Keuangan'),
                    items: _categories.map((cat) {
                      return DropdownMenuItem(value: cat, child: Text(cat));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  BlocBuilder<WalletCubit, WalletState>(
                    builder: (context, state) {
                      if (state is WalletSuccess) {
                        if (state.wallets.isNotEmpty) {
                          final keepId =
                              _selectedWallet?.id ??
                              (_isEditMode
                                  ? widget.initialTransaction?.walletId
                                  : null);
                          WalletEntity? matchingWallet;
                          for (final wallet in state.wallets) {
                            if (wallet.id == keepId) {
                              matchingWallet = wallet;
                              break;
                            }
                          }
                          _selectedWallet =
                              matchingWallet ?? state.wallets.first;
                        }
                        return DropdownButtonFormField<WalletEntity>(
                          initialValue: _selectedWallet,
                          style: TextStyle(color: primaryText),
                          dropdownColor: cardColor,
                          decoration: fieldDecoration(
                            labelText: 'Sumber Dompet / Kas',
                          ),
                          items: state.wallets.map((w) {
                            return DropdownMenuItem(
                              value: w,
                              child: Text(
                                '${w.name} (Saldo: Rp ${w.balance})',
                                style: TextStyle(color: primaryText),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedWallet = val);
                            }
                          },
                        );
                      }
                      return const LinearProgressIndicator(
                        color: AppColors.accentBlue,
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: BlocBuilder<TransactionCubit, TransactionState>(
                      builder: (context, state) {
                        if (state is DataLoading) {
                          return const Center(
                            child: CircularProgressIndicator.adaptive(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.accentBlue,
                              ),
                            ),
                          );
                        }
                        return FilledButton.icon(
                          onPressed: _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.accentBlue,
                            foregroundColor: Colors.white,
                          ),
                          icon: Icon(
                            _isEditMode ? AppIcons.edit : AppIcons.save,
                          ),
                          label: Text(
                            _isEditMode
                                ? 'Perbarui Transaksi'
                                : 'Simpan Transaksi',
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
