import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/gemini_ai_service.dart';
import '../../../../core/ui/app_icons.dart';
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
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(AppIcons.aiActive, color: AppIcons.aiColor),
                SizedBox(width: 8),
                Text('Gemini AI Express Input'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: promptCtrl,
                  enabled: !isLoading,
                  decoration: const InputDecoration(
                    hintText: 'Bebas, misal: kopi 18rb pakai gopay / gajian 2jt masuk bca',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (isLoading) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text(
                    'Gemini sedang menganalisis & menyimpan...',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
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
                            : const ['Gopay', 'BCA', 'Cash'];

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
                              backgroundColor: Colors.orange,
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
    );
  }

  /// Menyimpan hasil parsing AI: cocokkan dompet, catat transaksi, update saldo dompet (bukan membuat dompet baru).
  Future<void> _saveAiResult(Map<String, dynamic> result, String prompt) async {
    final walletCubit = context.read<WalletCubit>();
    final txCubit = context.read<TransactionCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    final walletState = walletCubit.state;
    if (walletState is! WalletSuccess || walletState.wallets.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Data dompet belum siap, coba lagi.'),
          backgroundColor: Colors.orange,
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
        SnackBar(content: Text(balanceError), backgroundColor: Colors.red),
      );
      return;
    }

    final adjusted = await walletCubit.adjustBalance(
      wallet.id,
      TransactionBalanceRules.effect(
        isIncome ? TransactionType.income : TransactionType.expense,
        amount,
      ),
    );
    if (!adjusted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Saldo dompet gagal diperbarui. Transaksi tidak disimpan.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    txCubit.add(
      TransactionEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        amount: amount,
        date: DateTime.now(),
        category: category,
        type: isIncome ? TransactionType.income : TransactionType.expense,
        walletId: wallet.id,
        walletName: wallet.name,
      ),
    );

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Tercatat: $title (Rp $amount) via ${wallet.name}'
          '${matched == null ? ' • metode bayar tidak disebut, dipakai ${wallet.name}' : ''}',
        ),
        backgroundColor: Colors.green,
      ),
    );
    router.pop();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      if (_selectedWallet == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pilih sumber dompet terlebih dahulu!'),
            backgroundColor: Colors.orange,
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
          SnackBar(content: Text(balanceError), backgroundColor: Colors.red),
        );
        return;
      }

      final txData = TransactionEntity(
        id: _isEditMode
            ? widget.initialTransaction!.id
            : DateTime.now().millisecondsSinceEpoch.toString(),
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
      int effect(TransactionType t, int a) =>
          TransactionBalanceRules.effect(t, a);

      if (_isEditMode) {
        final old = widget.initialTransaction!;
        // batalkan efek transaksi lama, lalu terapkan efek yang baru
        if (old.walletId == _selectedWallet!.id) {
          final adjusted = await walletCubit.adjustBalance(
            old.walletId,
            -effect(old.type, old.amount) + effect(_selectedType, amount),
          );
          if (!adjusted) return;
        } else {
          final restored = await walletCubit.adjustBalance(
            old.walletId,
            -effect(old.type, old.amount),
          );
          if (!restored) return;
          final applied = await walletCubit.adjustBalance(
            _selectedWallet!.id,
            effect(_selectedType, amount),
          );
          if (!applied) {
            await walletCubit.adjustBalance(
              old.walletId,
              effect(old.type, old.amount),
            );
            return;
          }
        }
        txCubit.update(txData);
      } else {
        final adjusted = await walletCubit.adjustBalance(
          _selectedWallet!.id,
          effect(_selectedType, amount),
        );
        if (!adjusted) return;
        txCubit.add(txData);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode ? 'Edit Transaksi' : 'Catat Keuangan Mahasiswa',
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
                backgroundColor: Colors.green,
              ),
            );
            context.pop();
          } else if (state is DataError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
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
                        color: AppIcons.aiColor,
                      ),
                      label: const Text(
                        'Isi & Simpan Otomatis Pakai Gemini AI 🪄',
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        side: const BorderSide(color: Colors.purpleAccent),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  SegmentedButton<TransactionType>(
                    segments: const [
                      ButtonSegment(
                        value: TransactionType.expense,
                        label: Text('Pengeluaran'),
                        icon: Icon(AppIcons.expense, color: Colors.redAccent),
                      ),
                      ButtonSegment(
                        value: TransactionType.income,
                        label: Text('Pemasukan'),
                        icon: Icon(AppIcons.income, color: Colors.greenAccent),
                      ),
                    ],
                    selected: {_selectedType},
                    onSelectionChanged: (Set<TransactionType> newSelection) {
                      setState(() {
                        _selectedType = newSelection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Transaksi',
                      hintText: 'Misal: ChatGPT Plus / Kopi Kenangan',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty)
                        ? 'Nama transaksi wajib diisi!'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _amountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nominal (Rp)',
                      hintText: 'Misal: 50000',
                      border: OutlineInputBorder(),
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
                    decoration: const InputDecoration(
                      labelText: 'Kategori Keuangan',
                      border: OutlineInputBorder(),
                    ),
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
                          _selectedWallet = state.wallets.firstWhere(
                            (w) => w.id == keepId,
                            orElse: () => state.wallets.first,
                          );
                        }
                        return DropdownButtonFormField<WalletEntity>(
                          initialValue: _selectedWallet,
                          decoration: const InputDecoration(
                            labelText: 'Sumber Dompet / Kas',
                            border: OutlineInputBorder(),
                          ),
                          items: state.wallets.map((w) {
                            return DropdownMenuItem(
                              value: w,
                              child: Text('${w.name} (Saldo: Rp ${w.balance})'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedWallet = val);
                            }
                          },
                        );
                      }
                      return const LinearProgressIndicator();
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
                            child: CircularProgressIndicator.adaptive(),
                          );
                        }
                        return FilledButton.icon(
                          onPressed: _submit,
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
