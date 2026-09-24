import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/transaction_entity.dart';
import '../cubit/transaction_cubit.dart';
import '../cubit/transaction_state.dart';

class TransactionFormPage extends StatefulWidget {
  const TransactionFormPage({super.key});

  @override
  State<TransactionFormPage> createState() => _TransactionFormPageState();
}

class _TransactionFormPageState extends State<TransactionFormPage> {
  // GlobalKey untuk validasi form terpusat (Modul 4)
  final _formKey = GlobalKey<FormState>();
  
  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _amountCtrl = TextEditingController();
  }

  @override
  void dispose() {
    // WAJIB: Membersihkan controller untuk mencegah kebocoran memori (Modul 4)
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    // WAJIB: Menutup keyboard virtual HP saat submit (Modul 4)
    FocusScope.of(context).unfocus();

    if (_formKey.currentState!.validate()) {
      final newTx = TransactionEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleCtrl.text.trim(),
        amount: int.parse(_amountCtrl.text.trim()),
        date: DateTime.now(),
      );
      
      // Panggil aksi tambah di Cubit
      context.read<TransactionCubit>().add(newTx);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tambah Transaksi')),
      // BlocListener khusus untuk menangani Side Effects seperti SnackBar & Navigasi (Modul 6)
      body: BlocListener<TransactionCubit, TransactionState>(
        listener: (context, state) {
          if (state is DataSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Transaksi berhasil disimpan!'),
                backgroundColor: Colors.green,
              ),
            );
            context.pop(); // Kembali ke Dashboard via GoRouter (Modul 4)
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
          // SingleChildScrollView agar form tidak overflow saat keyboard muncul (Modul 3)
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // TextFormField untuk Judul
                  TextFormField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Judul Transaksi',
                      hintText: 'Misal: Beli Kopi Kampus',
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Judul transaksi wajib diisi!';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // TextFormField untuk Nominal
                  TextFormField(
                    controller: _amountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nominal (Rp)',
                      hintText: 'Misal: 25000',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Nominal wajib diisi!';
                      }
                      if (int.tryParse(val.trim()) == null) {
                        return 'Nominal harus berupa angka valid!';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Tombol Submit
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: BlocBuilder<TransactionCubit, TransactionState>(
                      builder: (context, state) {
                        if (state is DataLoading) {
                          return const Center(child: CircularProgressIndicator.adaptive());
                        }
                        return FilledButton(
                          onPressed: _submit,
                          child: const Text('Simpan Transaksi'),
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