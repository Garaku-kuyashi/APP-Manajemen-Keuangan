import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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

  void _submit() {
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      if (_selectedWallet == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pilih sumber dompet terlebih dahulu!'), backgroundColor: Colors.orange),
        );
        return;
      }

      final amount = int.parse(_amountCtrl.text.trim());

      final txData = TransactionEntity(
        id: _isEditMode ? widget.initialTransaction!.id : DateTime.now().millisecondsSinceEpoch.toString(),
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

        // Update Saldo Dompet untuk transaksi baru
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
      appBar: AppBar(title: Text(_isEditMode ? 'Edit Transaksi' : 'Catat Keuangan Mahasiswa')),
      body: BlocListener<TransactionCubit, TransactionState>(
        listener: (context, state) {
          if (state is DataSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(_isEditMode ? 'Transaksi berhasil diperbarui!' : 'Transaksi berhasil dicatat!'),
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
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Nama transaksi wajib diisi!' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _amountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nominal (Rp)',
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