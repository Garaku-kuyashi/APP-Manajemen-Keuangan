import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/gemini_ai_service.dart';
import '../../../../core/ui/app_icons.dart';
import '../../../../core/utils/wallet_matcher.dart';
import '../../../transaction/domain/entities/transaction_entity.dart';
import '../../../transaction/presentation/cubit/transaction_cubit.dart';
import '../../../transaction/presentation/cubit/transaction_state.dart';
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
        text: 'Halo! Aku MyMoney AI 🤖\nBisa curhat soal uang saku, minta saran hemat, atau langsung bilang aja misal "jajan boba 20rb pakai gopay", nanti aku catat. Lagi mikirin apa nih?',
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

    // Riwayat sebelum pesan ini (jadi memori obrolan untuk AI)
    final history = _messages.map((m) => AiTurn(text: m.text, isUser: m.isUser)).toList();

    setState(() {
      _messages.add(ChatMessage(text: userText, isUser: true));
      _isLoading = true;
    });
    _msgCtrl.clear();

    final walletCubit = context.read<WalletCubit>();
    final txCubit = context.read<TransactionCubit>();

    // Pastikan data dompet sudah termuat
    if (walletCubit.state is! WalletSuccess) await walletCubit.loadWallets();
    final walletState = walletCubit.state;
    final txState = txCubit.state;
    final currentTx = txState is DataSuccess ? txState.transactions : <TransactionEntity>[];

    final result = await GeminiAiService.processChatMessage(
      userMessage: userText,
      history: history,
      wallets: walletState is WalletSuccess ? walletState.wallets : const [],
      transactions: currentTx,
    );

    String replyText = result.reply;
    final tx = result.transaction;

    if (tx != null && walletState is WalletSuccess && walletState.wallets.isNotEmpty) {
      final allWallets = walletState.wallets;
      final matched = WalletMatcher.find(tx['wallet'] as String?, allWallets) ??
          WalletMatcher.find(userText, allWallets);
      final wallet = matched ?? WalletMatcher.fallback(allWallets);

      final amount = tx['amount'] as int;
      final title = tx['title'] as String;
      final isIncome = tx['type'] == 'income';

      // Update saldo dompet YANG SUDAH ADA (bukan membuat dompet baru)
      await walletCubit.adjustBalance(wallet.id, isIncome ? amount : -amount);
      txCubit.add(TransactionEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        amount: amount,
        date: DateTime.now(),
        category: tx['category'] as String,
        type: isIncome ? TransactionType.income : TransactionType.expense,
        walletId: wallet.id,
        walletName: wallet.name,
      ));

      // Mode tanpa AI: balasan kosong, buat konfirmasi sederhana
      if (replyText.isEmpty) {
        replyText = 'Oke, sudah kucatat: $title Rp $amount via ${wallet.name} 📝'
            '${matched == null ? ' (metode bayar tidak disebut, jadi pakai ${wallet.name})' : ''}';
      }
    } else if (replyText.isEmpty) {
      replyText = 'Hmm, aku belum bisa mencatatnya. Coba sebutkan nominalnya ya.';
    }

    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(text: replyText, isUser: false));
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(AppIcons.aiActive, color: AppIcons.aiColor),
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
                        hintText: 'Ketik bebas: tanya saldo, curhat, atau catat transaksi...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _handleSend,
                    icon: const Icon(AppIcons.send),
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