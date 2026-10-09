import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/gemini_ai_service.dart';
import '../../../wallet/domain/entities/wallet_entity.dart';
import '../../../wallet/presentation/cubit/wallet_cubit.dart';
import '../../../wallet/presentation/cubit/wallet_state.dart';
import '../../domain/entities/transaction_entity.dart';
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
    _amountCtrl = TextEditingController(text: tx != null ? tx.amount.toString() : '');

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
                Icon(Icons.auto_awesome, color: Colors.purpleAccent),
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
                    hintText: 'Misal: beli gemini pro dengan harga 65000 dengan menggunakan gopay',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (isLoading) ...[
                  const SizedBox(height: 16),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('Gemini sedang menganalisis & menyimpan...',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Proses & Simpan'),
                onPressed: isLoading
                    ? null
                    : () async {
                        final textPrompt = promptCtrl.text.trim();
                        if (textPrompt.isNotEmpty) {
                          setDialogState(() => isLoading = true);

                          final result = await GeminiAiService.parseTransactionPrompt(textPrompt);

                          if (mounted) {
                            setDialogState(() => isLoading = false);
                            Navigator.pop(ctx);

                            if (result != null) {
                              // Parsing angka nominal yang aman
                              final amount = result['amount'] is int
                                  ? result['amount'] as int
                                  : int.tryParse(result['amount'].toString()) ?? 0;
                              final title = result['title'] ?? 'Transaksi AI';
                              final category = result['category'] ?? _selectedCategory;
                              final isIncome = result['type'] == 'income';

                              // Deteksi dompet kas yang sesuai dari input (misal: "gopay")
                              final walletState = context.read<WalletCubit>().state;
                              WalletEntity? matchedWallet;

                              if (walletState is WalletSuccess && walletState.wallets.isNotEmpty) {
                                final lowerPrompt = textPrompt.toLowerCase();
                                matchedWallet = walletState.wallets.firstWhere(
                                  (w) => lowerPrompt.contains(w.name.toLowerCase()),
                                  orElse: () => walletState.wallets.first,
                                );
                              }

                              if (matchedWallet != null) {
                                final txData = TransactionEntity(
                                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                                  title: title,
                                  amount: amount,
                                  date: DateTime.now(),
                                  category: category,
                                  type: isIncome ? TransactionType.income : TransactionType.expense,
                                  walletId: matchedWallet.id,
                                  walletName: matchedWallet.name,
                                );

                                // PROSES AUTO-SAVE LANGSUNG KE STATE CUBIT!
                                context.read<TransactionCubit>().add(txData);

                                final newBalance = isIncome
                                    ? matchedWallet.balance + amount
                                    : matchedWallet.balance - amount;

                                context.read<WalletCubit>().add(
                                      WalletEntity(
                                        id: matchedWallet.id,
                                        name: matchedWallet.name,
                                        balance: newBalance,
                                        iconName: matchedWallet.iconName,
                                      ),
                                    );

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('AI Berhasil Mencatat: $title (Rp $amount) via ${matchedWallet.name}'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                context.pop(); // Langsung kembali ke Dashboard!
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Gagal mengekstrak teks. Coba gunakan kalimat yang lebih jelas.'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          }
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  void _submit() {
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

      if (_isEditMode) {
        context.read<TransactionCubit>().update(txData);
      } else {
        context.read<TransactionCubit>().add(txData);

        final newBalance = _selectedType == TransactionType.income
            ? _selectedWallet!.balance + amount
            : _selectedWallet!.balance - amount;

        context.read<WalletCubit>().add(
              WalletEntity(
                id: _selectedWallet!.id,
                name: _selectedWallet!.name,
                balance: newBalance,
                iconName: _selectedWallet!.iconName,
              ),
            );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Transaksi' : 'Catat Keuangan Mahasiswa'),
      ),
      body: BlocListener<TransactionCubit, TransactionState>(
        listener: (context, state) {
          if (state is DataSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _isEditMode ? 'Transaksi berhasil diperbarui!' : 'Transaksi berhasil dicatat!',
                ),
                backgroundColor: Colors.green,
              ),
            );
            context.pop();
          } else if (state is DataError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.red),
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
                      icon: const Icon(Icons.auto_awesome, color: Colors.purpleAccent),
                      label: const Text('Isi & Simpan Otomatis Pakai Gemini AI 🪄'),
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
                        icon: Icon(Icons.arrow_downward, color: Colors.redAccent),
                      ),
                      ButtonSegment(
                        value: TransactionType.income,
                        label: Text('Pemasukan'),
                        icon: Icon(Icons.arrow_upward, color: Colors.greenAccent),
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
                    validator: (val) =>
                        (val == null || val.trim().isEmpty) ? 'Nama transaksi wajib diisi!' : null,
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
                      if (val == null || val.trim().isEmpty) return 'Nominal wajib diisi!';
                      if (int.tryParse(val.trim()) == null) return 'Harus berupa angka valid!';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
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
                        if (_selectedWallet == null && state.wallets.isNotEmpty) {
                          _selectedWallet = state.wallets.firstWhere(
                            (w) => _isEditMode && w.id == widget.initialTransaction?.walletId,
                            orElse: () => state.wallets.first,
                          );
                        }
                        return DropdownButtonFormField<WalletEntity>(
                          value: _selectedWallet,
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
                            if (val != null) setState(() => _selectedWallet = val);
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
                          return const Center(child: CircularProgressIndicator.adaptive());
                        }
                        return FilledButton.icon(
                          onPressed: _submit,
                          icon: Icon(_isEditMode ? Icons.edit : Icons.save),
                          label: Text(_isEditMode ? 'Perbarui Transaksi' : 'Simpan Transaksi'),
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