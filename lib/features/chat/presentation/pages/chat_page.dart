import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/theme/app_colors.dart';
import '../../../../core/services/gemini_ai_service.dart';
import '../../../../core/di/theme/app_icons.dart';
import '../../../../core/utils/wallet_matcher.dart';
import '../../../transaction/domain/entities/transaction_entity.dart';
import '../../../transaction/domain/usecases/transaction_balance_rules.dart';
import '../../../transaction/presentation/cubit/transaction_cubit.dart';
import '../../../transaction/presentation/cubit/transaction_state.dart';
import '../../../wallet/presentation/cubit/wallet_cubit.dart';
import '../../../wallet/presentation/cubit/wallet_state.dart';
import '../../../wallet/domain/entities/wallet_entity.dart';
import '../../data/chat_repository.dart';

const _welcomeMessage =
    'Halo! Aku MyMoney AI 🤖\n'
    'Bisa curhat soal uang saku, minta saran hemat, atau langsung bilang aja '
    'misal "jajan boba 20rb pakai gopay", nanti aku catat. Lagi mikirin apa nih?';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _activeTopicId;
  bool _isCreatingTopic = false;
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startNewTopic() async {
    setState(() {
      _activeTopicId = null;
      _isCreatingTopic = true;
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final repository = context.read<ChatRepository>();
    final walletCubit = context.read<WalletCubit>();
    final transactionCubit = context.read<TransactionCubit>();
    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final isNewTopic = _activeTopicId == null;
      final topicId =
          _activeTopicId ??
          await repository.createTopic(text, welcomeMessage: _welcomeMessage);
      if (!mounted) return;
      setState(() {
        _activeTopicId = topicId;
        _isCreatingTopic = false;
      });

      final previousMessages = isNewTopic
          ? <ChatMessage>[]
          : await repository.getRecentMessages(topicId, limit: 20);
      await repository.addMessage(topicId: topicId, text: text, isUser: true);

      await walletCubit.loadWallets();
      await transactionCubit.loadTransactions();
      final walletState = walletCubit.state;
      final transactionState = transactionCubit.state;
      final wallets = walletState is WalletSuccess
          ? walletState.wallets
          : <WalletEntity>[];
      final transactions = transactionState is DataSuccess
          ? transactionState.transactions
          : <TransactionEntity>[];

      final result = await GeminiAiService.processChatMessage(
        userMessage: text,
        history: previousMessages
            .map(
              (message) => AiTurn(text: message.text, isUser: message.isUser),
            )
            .toList(),
        wallets: wallets,
        transactions: transactions,
      );

      var reply = result.reply;
      final parsedTransaction = result.transaction;
      if (parsedTransaction != null) {
        if (wallets.isEmpty) {
          reply = 'Buat dompet terlebih dahulu sebelum mencatat transaksi.';
        } else {
          final matched =
              WalletMatcher.find(
                parsedTransaction['wallet'] as String?,
                wallets,
              ) ??
              WalletMatcher.find(text, wallets);
          final wallet = matched ?? WalletMatcher.fallback(wallets);
          final isIncome = parsedTransaction['type'] == 'income';
          final type = isIncome
              ? TransactionType.income
              : TransactionType.expense;
          final amount = parsedTransaction['amount'] as int;
          final validationError = TransactionBalanceRules.validateAmount(
            amount: amount,
            type: type,
            availableBalance: wallet.balance,
          );

          if (validationError != null) {
            reply = validationError;
          } else {
            final saved = await transactionCubit.add(
              TransactionEntity(
                id: DateTime.now().microsecondsSinceEpoch.toString(),
                title: parsedTransaction['title'] as String,
                amount: amount,
                date: DateTime.now(),
                category: parsedTransaction['category'] as String,
                type: type,
                walletId: wallet.id,
                walletName: wallet.name,
              ),
            );
            if (saved) {
              await walletCubit.loadWallets();
              if (reply.isEmpty) {
                reply = 'Sudah kucatat Rp $amount via ${wallet.name}.';
              }
            } else {
              final errorState = transactionCubit.state;
              reply = errorState is DataError
                  ? 'Transaksi gagal disimpan: ${errorState.message}'
                  : 'Transaksi gagal disimpan. Coba lagi.';
            }
          }
        }
      }
      if (reply.trim().isEmpty) {
        reply = 'Maaf, aku belum bisa menjawab. Coba tanyakan lagi ya.';
      }

      await repository.addMessage(topicId: topicId, text: reply, isUser: false);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Chat gagal disimpan: $error')),
          );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _deleteTopic(ChatTopic topic) async {
    try {
      await context.read<ChatRepository>().deleteTopic(topic.id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Topik gagal dihapus: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.read<ChatRepository>();
    final activeTopicId = _activeTopicId;
    final isThread = activeTopicId != null || _isCreatingTopic;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBackground = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final appBarColor = isDark
        ? AppColors.surface
        : AppColors.lightBackgroundCard;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.primaryText;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: primaryText,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: borderColor),
        ),
        leading: isThread
            ? IconButton(
                tooltip: 'Daftar topik',
                onPressed: _isSending
                    ? null
                    : () => setState(() {
                        _activeTopicId = null;
                        _isCreatingTopic = false;
                      }),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              const Icon(AppIcons.aiActive, color: AppColors.accentBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isThread ? 'Percakapan AI' : 'Teman Keuangan AI',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              tooltip: 'Topik baru',
              onPressed: _isSending ? null : _startNewTopic,
              icon: const Icon(Icons.add_comment_outlined),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: isThread
            ? _buildThread(repository, activeTopicId)
            : _buildTopicList(repository),
      ),
    );
  }

  Widget _buildTopicList(ChatRepository repository) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark
        ? AppColors.surface
        : AppColors.lightBackgroundCard;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.primaryText;
    final secondaryText = isDark
        ? AppColors.textSecondary
        : AppColors.secondaryText;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return StreamBuilder<List<ChatTopic>>(
      stream: repository.watchTopics(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Gagal memuat topik: ${snapshot.error}',
              style: TextStyle(color: primaryText),
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        final topics = snapshot.data ?? const <ChatTopic>[];
        if (topics.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.forum_outlined,
                    size: 52,
                    color: AppColors.accentBlue,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada topik percakapan.',
                    style: TextStyle(color: primaryText),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentBlue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _startNewTopic,
                    icon: const Icon(Icons.add),
                    label: const Text('Mulai percakapan'),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: topics.length,
          separatorBuilder: (_, _) => const SizedBox(height: 4),
          itemBuilder: (context, index) {
            final topic = topics[index];
            return Card(
              color: cardColor,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: borderColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isDark
                      ? AppColors.background
                      : AppColors.lightNavigation,
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.accentBlue,
                  ),
                ),
                title: Text(
                  topic.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _formatDate(topic.updatedAt),
                  style: TextStyle(color: secondaryText),
                ),
                onTap: () => setState(() {
                  _activeTopicId = topic.id;
                  _isCreatingTopic = false;
                }),
                trailing: IconButton(
                  tooltip: 'Hapus topik',
                  onPressed: () => _deleteTopic(topic),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.negative,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThread(ChatRepository repository, String? topicId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimary : AppColors.primaryText;
    final secondaryText = isDark
        ? AppColors.textSecondary
        : AppColors.secondaryText;
    final inputBackground = isDark
        ? AppColors.background
        : AppColors.lightInputBackground;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Column(
      children: [
        Expanded(
          child: topicId == null
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildMessage(
                      ChatMessage(
                        id: 'welcome',
                        text: _welcomeMessage,
                        isUser: false,
                        createdAt: DateTime.now(),
                      ),
                    ),
                  ],
                )
              : StreamBuilder<List<ChatMessage>>(
                  stream: repository.watchMessages(topicId),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Gagal memuat pesan: ${snapshot.error}',
                          style: TextStyle(color: primaryText),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator.adaptive(),
                      );
                    }
                    final messages = snapshot.data ?? const <ChatMessage>[];
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(
                          _scrollController.position.maxScrollExtent,
                        );
                      }
                    });
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) =>
                          _buildMessage(messages[index]),
                    );
                  },
                ),
        ),
        if (_isSending)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.accentBlue,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'AI sedang menganalisis...',
                  style: TextStyle(color: secondaryText),
                ),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surface : AppColors.lightBackgroundCard,
            border: Border(top: BorderSide(color: borderColor)),
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  enabled: !_isSending,
                  style: TextStyle(color: primaryText),
                  decoration: InputDecoration(
                    hintText: 'Tanya atau ceritakan soal keuangan...',
                    hintStyle: TextStyle(color: secondaryText),
                    filled: true,
                    fillColor: inputBackground,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
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
                        width: 1.5,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isSending ? null : _sendMessage,
                icon: const Icon(AppIcons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessage(ChatMessage message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = message.isUser
        ? AppColors.accentBlue
        : (isDark ? AppColors.surface : AppColors.lightNavigation);
    final textColor = message.isUser
        ? Colors.white
        : (isDark ? AppColors.textPrimary : AppColors.primaryText);
    final bubbleBorder = !message.isUser
        ? Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          )
        : null;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          border: bubbleBorder,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(message.text, style: TextStyle(color: textColor)),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(local.day)}/${twoDigits(local.month)}/${local.year} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}
