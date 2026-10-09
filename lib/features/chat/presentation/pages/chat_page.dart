import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/gemini_ai_service.dart';
import '../../../transaction/domain/entities/transaction_entity.dart';
import '../../../transaction/presentation/cubit/transaction_cubit.dart';
import '../../../transaction/presentation/cubit/transaction_state.dart';
import '../../../wallet/domain/entities/wallet_entity.dart';
import '../../../wallet/presentation/cubit/wallet_cubit.dart';
import '../../../wallet/presentation/cubit/wallet_state.dart';

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _msgCtrl = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Memuat data dompet & transaksi terbaru saat tab diklik
    context.read<WalletCubit>().loadWallets();
    context.read<TransactionCubit>().loadTransactions();

    _messages.add(
      ChatMessage(
        text: 'Halo! Aku MyMoney AI 🤖\nAku bisa lihat sisa uang sakumu dan bantu jawab curhat keuangan kampus, kasih saran hemat, atau langsung catat transaksi secara otomatis. Mau ngobrolin apa nih?',
        isUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSend() async {
    final userText = _msgCtrl.text.trim();
    if (userText.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(text: userText, isUser: true));
      _isLoading = true;
    });
    _msgCtrl.clear();

    // 1. Ambil Sisa Saldo Total secara Realtime dari WalletCubit
    int totalWalletBalance = 0;
    final walletState = context.read<WalletCubit>().state;
    if (walletState is WalletSuccess) {
      for (var w in walletState.wallets) {
        totalWalletBalance += w.balance;
      }
    }

    // 2. Ambil Riwayat Transaksi dari TransactionCubit
    List<TransactionEntity> currentTx = [];
    final txState = context.read<TransactionCubit>().state;
    if (txState is DataSuccess) {
      currentTx = txState.transactions;
    }

    // 3. Cek apakah ini instruksi pencatatan transaksi
    final parseResult = await GeminiAiService.parseTransactionPrompt(userText);

    if (parseResult != null && 
        parseResult['amount'] != null && 
        parseResult['amount'] is int && 
        (parseResult['amount'] as int) > 0 &&
        (userText.toLowerCase().contains('beli') || 
         userText.toLowerCase().contains('bayar') || 
         userText.toLowerCase().contains('dapat') || 
         userText.toLowerCase().contains('isi'))) {
      
      final amount = parseResult['amount'] as int;
      final title = parseResult['title'] ?? 'Transaksi AI';
      final category = parseResult['category'] ?? 'Lainnya';
      final isIncome = parseResult['type'] == 'income';

      WalletEntity? matchedWallet;
      if (walletState is WalletSuccess && walletState.wallets.isNotEmpty) {
        final lowerText = userText.toLowerCase();
        matchedWallet = walletState.wallets.firstWhere(
          (w) => lowerText.contains(w.name.toLowerCase()),
          orElse: () => walletState.wallets.first,
        );
      }

      if (matchedWallet != null && mounted) {
        final newTx = TransactionEntity(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: title,
          amount: amount,
          date: DateTime.now(),
          category: category,
          type: isIncome ? TransactionType.income : TransactionType.expense,
          walletId: matchedWallet.id,
          walletName: matchedWallet.name,
        );

        // Simpan Transaksi & Potong/Tambah Saldo Dompet
        context.read<TransactionCubit>().add(newTx);
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

        setState(() {
          _messages.add(
            ChatMessage(
              text: 'Sip, udah aku catat ya! 📝\n'
                  '• Judul: $title\n'
                  '• Nominal: Rp $amount\n'
                  '• Sumber: ${matchedWallet!.name}\n\n'
                  'Sisa total uang kamu sekarang: Rp ${isIncome ? totalWalletBalance + amount : totalWalletBalance - amount}.',
              isUser: false,
            ),
          );
        });
      }
    } else {
      // 4. Jika Obrolan Biasa / Tanya Sisa Saldo / Curhat Finansial
      final aiReply = await GeminiAiService.chatWithStudentAdvisor(
        userMessage: userText,
        transactions: currentTx,
        totalBalance: totalWalletBalance,
      );

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(text: aiReply, isUser: false));
        });
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.purpleAccent),
            SizedBox(width: 8),
            Text('Teman Keuangan AI'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return Align(
                    alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.78,
                      ),
                      decoration: BoxDecoration(
                        color: msg.isUser
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        msg.text,
                        style: TextStyle(
                          color: msg.isUser
                              ? Theme.of(context).colorScheme.onPrimaryContainer
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('AI sedang menganalisis...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Tanya sisa saldo atau curhat...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _handleSend,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}