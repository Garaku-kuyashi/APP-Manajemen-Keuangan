import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/transaction/domain/entities/transaction_entity.dart';
import '../../features/wallet/domain/entities/wallet_entity.dart';
import 'api_config.dart';

/// Satu giliran percakapan (dipakai sebagai memori obrolan).
class AiTurn {
  final String text;
  final bool isUser;
  const AiTurn({required this.text, required this.isUser});
}

/// Hasil satu pesan chat: balasan natural + (opsional) transaksi yang terdeteksi.
class AiChatResult {
  /// Balasan natural dari AI. Bisa kosong jika AI tidak tersedia (mode fallback).
  final String reply;

  /// Data transaksi ter-normalisasi: title, amount(int), category, type, wallet(String?)
  final Map<String, dynamic>? transaction;

  const AiChatResult({required this.reply, this.transaction});
}

class GeminiAiService {
  static const String _apiKey = ApiConfig.geminiApiKey;

  // Key dikirim lewat header (bukan di URL) supaya tidak bocor di log.
  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  static const List<String> categories = [
    'Makan & Kopi',
    'Langganan AI',
    'Hiburan & Streaming',
    'Kuota & Internet',
    'Kebutuhan Kuliah',
    'Uang Saku',
    'Lainnya',
  ];

  // ---------------------------------------------------------------------------
  // LOW-LEVEL: panggil Gemini & ambil JSON
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>?> _callJson({
    required String systemInstruction,
    required List<Map<String, dynamic>> contents,
    double temperature = 0.3,
  }) async {
    if (_apiKey.isEmpty) {
      // ignore: avoid_print
      print(
        'GEMINI_API_KEY KOSONG. Jalankan dengan --dart-define-from-file=env.json',
      );
      return null;
    }
    try {
      final response = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': _apiKey,
            },
            body: jsonEncode({
              'systemInstruction': {
                'parts': [
                  {'text': systemInstruction},
                ],
              },
              'contents': contents,
              'generationConfig': {
                'temperature': temperature,
                'responseMimeType': 'application/json',
                'thinkingConfig': {'thinkingBudget': 0},
              },
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        // ignore: avoid_print
        print('Gemini error (${response.statusCode}): ${response.body}');
        return null;
      }

      final data = jsonDecode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
      if (text is! String || text.trim().isEmpty) return null;
      return _extractJson(text);
    } catch (e) {
      // ignore: avoid_print
      print('Gemini exception: $e');
      return null;
    }
  }

  /// Ambil objek JSON pertama dari teks, walau dibungkus ```json atau ada teks lain.
  static Map<String, dynamic>? _extractJson(String raw) {
    final start = raw.indexOf('{');
    final end = raw.lastIndexOf('}');
    if (start == -1 || end <= start) return null;
    try {
      final obj = jsonDecode(raw.substring(start, end + 1));
      if (obj is Map<String, dynamic>) return obj;
    } catch (_) {}
    return null;
  }

  // ---------------------------------------------------------------------------
  // NORMALISASI & PARSER LOKAL (cadangan jika AI gagal / kalimat acak)
  // ---------------------------------------------------------------------------

  static final RegExp _amountRe = RegExp(
    r'(\d+(?:[.,]\d+)*)\s*(rb|ribu|k|jt|juta)?(?![a-z0-9])',
    caseSensitive: false,
  );

  /// Baca nominal dari teks: 25000, 25.000, 25rb, 25k, 1,5jt, 2 juta.
  /// Mengambil kandidat terbesar (>= 100) supaya "2 kopi 30rb" -> 30000.
  static int? _amountFromText(String text) {
    int? best;
    for (final m in _amountRe.allMatches(text.toLowerCase())) {
      final numStr = m.group(1)!;
      final suffix = (m.group(2) ?? '').toLowerCase();
      double value;
      if (suffix.isEmpty) {
        value =
            double.tryParse(numStr.replaceAll('.', '').replaceAll(',', '')) ??
            0;
      } else {
        value = double.tryParse(numStr.replaceAll(',', '.')) ?? 0;
        if (suffix == 'rb' || suffix == 'ribu' || suffix == 'k') value *= 1000;
        if (suffix == 'jt' || suffix == 'juta') value *= 1000000;
      }
      final v = value.round();
      if (v >= 100 && (best == null || v > best)) best = v;
    }
    return best;
  }

  static int? _toAmount(dynamic raw, String originalText) {
    if (raw is num) return raw.round();
    if (raw is String) {
      final a = _amountFromText(raw);
      if (a != null) return a;
      final digits = int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), ''));
      if (digits != null) return digits;
    }
    return _amountFromText(originalText);
  }

  static String _validCategory(dynamic raw) {
    if (raw is String) {
      for (final c in categories) {
        if (c.toLowerCase() == raw.trim().toLowerCase()) return c;
      }
    }
    return 'Lainnya';
  }

  static Map<String, dynamic>? _normalize(
    Map<String, dynamic> raw,
    String originalText,
  ) {
    final amount = _toAmount(raw['amount'], originalText);
    if (amount == null || amount <= 0) return null;

    String title = (raw['title'] ?? '').toString().trim();
    if (title.isEmpty) title = _localTitle(originalText);

    final type = (raw['type'] ?? '').toString().toLowerCase() == 'income'
        ? 'income'
        : 'expense';
    final walletRaw = raw['wallet'];
    final wallet =
        (walletRaw is String &&
            walletRaw.trim().isNotEmpty &&
            walletRaw.toLowerCase() != 'null')
        ? walletRaw.trim()
        : null;

    return {
      'title': title,
      'amount': amount,
      'category': _validCategory(raw['category']),
      'type': type,
      'wallet': wallet,
    };
  }

  static const List<String> _incomeWords = [
    'gaji',
    'gajian',
    'uang saku',
    'kiriman',
    'dikirim',
    'dapat',
    'dapet',
    'terima',
    'nerima',
    'bonus',
    'honor',
    'cashback',
    'pemasukan',
    'masuk',
  ];
  static const List<String> _spendWords = [
    'beli',
    'bayar',
    'jajan',
    'makan',
    'minum',
    'isi',
    'topup',
    'top up',
    'langganan',
    'abis',
    'habis',
    'keluar',
    'traktir',
    'pengeluaran',
    'sewa',
    'ongkos',
    'parkir',
    'bensin',
  ];

  static String _localCategory(String lower) {
    bool has(List<String> w) => w.any(lower.contains);
    if (has(['gaji', 'uang saku', 'kiriman'])) return 'Uang Saku';
    if (has([
          'gemini',
          'chatgpt',
          'claude',
          'copilot',
          'midjourney',
          'perplexity',
          'cursor',
        ]) ||
        RegExp(r'\bai\b').hasMatch(lower)) {
      return 'Langganan AI';
    }
    if (has([
      'netflix',
      'spotify',
      'youtube',
      'disney',
      'vidio',
      'bioskop',
      'game',
      'steam',
    ])) {
      return 'Hiburan & Streaming';
    }
    if (has(['kuota', 'pulsa', 'internet', 'wifi', 'paket data']))
      return 'Kuota & Internet';
    if (has([
      'print',
      'fotokopi',
      'buku',
      'kuliah',
      'tugas',
      'ukt',
      'alat tulis',
      'skripsi',
    ])) {
      return 'Kebutuhan Kuliah';
    }
    if (has([
      'makan',
      'kopi',
      'jajan',
      'minum',
      'nasi',
      'ayam',
      'bakso',
      'mie',
      'boba',
      'snack',
      'sarapan',
    ])) {
      return 'Makan & Kopi';
    }
    return 'Lainnya';
  }

  static String _localTitle(String text) {
    var t = text.toLowerCase();
    t = t.replaceAll(_amountRe, ' ');
    const filler = [
      'dengan',
      'menggunakan',
      'pakai',
      'pake',
      'via',
      'lewat',
      'dari',
      'saya',
      'aku',
      'harga',
      'seharga',
      'sebesar',
      'rp',
      'rupiah',
      'untuk',
      'dan',
      'yang',
      'di',
      'ke',
      'beli',
      'bayar',
      'tadi',
      'barusan',
      'catat',
      'tolong',
      'gopay',
      'ovo',
      'dana',
      'bca',
      'cash',
      'tunai',
    ];
    final words = t
        .split(RegExp(r'[^a-z0-9&]+'))
        .where((w) => w.isNotEmpty && !filler.contains(w))
        .toList();
    if (words.isEmpty) return 'Transaksi';
    final joined = words.join(' ');
    return joined[0].toUpperCase() + joined.substring(1);
  }

  static bool _looksLikeTransaction(String text) {
    final lower = text.toLowerCase();
    if (_amountFromText(lower) == null) return false;
    return _incomeWords.any(lower.contains) || _spendWords.any(lower.contains);
  }

  /// Parser tanpa AI: tahan terhadap urutan kalimat acak.
  static Map<String, dynamic>? _localParse(String text) {
    final amount = _amountFromText(text);
    if (amount == null) return null;
    final lower = text.toLowerCase();
    final isIncome =
        _incomeWords.any(lower.contains) && !_spendWords.any(lower.contains);
    return {
      'title': _localTitle(text),
      'amount': amount,
      'category': _localCategory(lower),
      'type': isIncome ? 'income' : 'expense',
      'wallet': null, // dompet dicocokkan oleh WalletMatcher dari teks asli
    };
  }

  // ---------------------------------------------------------------------------
  // PUBLIC: parser untuk "Isi & Simpan Otomatis" di form
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>?> parseTransactionPrompt(
    String userPrompt, {
    List<String> walletNames = const [],
  }) async {
    final today = DateTime.now().toString().substring(0, 10);
    final system =
        '''
Kamu adalah mesin ekstraksi transaksi keuangan untuk aplikasi MyMoney (mahasiswa Indonesia).
Pengguna menulis bebas: urutan kata bisa acak, ada typo, singkatan, bahasa gaul. Pahami maksudnya, jangan kaku pada template.
Tanggal hari ini: $today.

Keluarkan HANYA JSON dengan bentuk:
{"is_transaction": boolean, "title": string, "amount": integer, "category": string, "type": "expense" | "income", "wallet": string | null}

Aturan:
- amount: bilangan bulat rupiah. Ubah "25rb"/"25k"/"25 ribu" -> 25000, "1,5jt"/"1.5 juta" -> 1500000, "25.000" -> 25000.
- title: nama transaksi singkat dan rapi (mis. "Gemini Pro", "Kopi Kenangan"), tanpa nominal & tanpa nama dompet.
- category: pilih persis salah satu dari ${categories.map((c) => '"$c"').join(', ')}.
- type: "income" jika uang masuk (gaji, uang saku, dikirim, dapat, terima, bonus), selain itu "expense".
- wallet: pilih persis salah satu dari ${walletNames.map((c) => '"$c"').join(', ')} jika metode pembayaran cocok dengan nama dompet yang tersedia. Jika tidak ada dompet yang cocok, daftar kosong, atau metode tidak disebut, isi null. Jangan mengarang nama dompet.
- Jika teks bukan catatan transaksi atau tidak ada nominal, isi is_transaction=false dan amount=0.

Contoh:
Input: "dengan 25000 saya beli gemini"
Output: {"is_transaction": true, "title": "Gemini", "amount": 25000, "category": "Langganan AI", "type": "expense", "wallet": null}
Input: "kepotong 18rb buat kopi"
Output: {"is_transaction": true, "title": "Kopi", "amount": 18000, "category": "Makan & Kopi", "type": "expense", "wallet": null}
Input: "dapat kiriman ortu 1,5jt"
Output: {"is_transaction": true, "title": "Kiriman Orang Tua", "amount": 1500000, "category": "Uang Saku", "type": "income", "wallet": null}
''';

    final json = await _callJson(
      systemInstruction: system,
      contents: [
        {
          'role': 'user',
          'parts': [
            {'text': userPrompt},
          ],
        },
      ],
      temperature: 0.1,
    );

    if (json != null && json['is_transaction'] != false) {
      final normalized = _normalize(json, userPrompt);
      if (normalized != null) return normalized;
    }
    // AI gagal / tidak yakin -> coba parser lokal agar tetap tercatat.
    return _localParse(userPrompt);
  }

  // ---------------------------------------------------------------------------
  // PUBLIC: chat natural + deteksi transaksi dalam satu panggilan
  // ---------------------------------------------------------------------------

  static Future<AiChatResult> processChatMessage({
    required String userMessage,
    required List<AiTurn> history,
    required List<WalletEntity> wallets,
    required List<TransactionEntity> transactions,
  }) async {
    final totalBalance = wallets.fold<int>(0, (s, w) => s + w.balance);
    final walletLines = wallets
        .map((w) => '- ${w.name}: Rp ${w.balance}')
        .join('\n');
    final defaultWallet = wallets.isNotEmpty
        ? wallets.first.name
        : 'belum ada dompet';

    final recent = transactions
        .take(10)
        .map(
          (t) =>
              '- ${t.date.toString().substring(0, 10)} | ${t.title} (${t.category}) | ${t.type == TransactionType.income ? '+' : '-'}Rp ${t.amount} | ${t.walletName}',
        )
        .join('\n');

    final spendByCat = <String, int>{};
    for (final t in transactions) {
      if (t.type == TransactionType.expense) {
        spendByCat[t.category] = (spendByCat[t.category] ?? 0) + t.amount;
      }
    }
    final catLines = spendByCat.entries
        .map((e) => '- ${e.key}: Rp ${e.value}')
        .join('\n');

    final system =
        '''
Kamu adalah "MyMoney AI", teman ngobrol sekaligus pendamping keuangan untuk mahasiswa Indonesia.

KEPRIBADIAN
- Hangat, santai, empatik, seperti teman kampus yang melek finansial. Pakai "aku/kamu".
- Balasan natural dan bervariasi, jangan seperti template. Tidak perlu selalu pakai bullet. Emoji secukupnya.
- Panjang menyesuaikan: sapaan/ringan 1-2 kalimat, curhat atau minta saran 3-5 kalimat. Boleh bertanya balik.
- Ingat isi percakapan sebelumnya dan nyambung ke situ.
- Boleh ngobrol hal di luar keuangan sebentar, lalu arahkan lembut ke topik uang jika relevan.
- Jangan menghakimi pengeluaran. Beri saran praktis dan realistis.
- Jangan mengarang angka. Pakai hanya data di bawah.

DATA KEUANGAN SAAT INI
Total saldo semua dompet: Rp $totalBalance
Saldo per dompet:
$walletLines
Pengeluaran per kategori:
${catLines.isEmpty ? '(belum ada)' : catLines}
Transaksi terbaru:
${recent.isEmpty ? '(belum ada)' : recent}

TUGAS
Tentukan maksud pesan terakhir pengguna:
1) Pengguna MELAPORKAN uang yang sudah keluar/masuk (urutan kata bebas, boleh typo/gaul, misal "jajan boba 20rb pake gopay", "dapat gaji 2jt", "abis 25000 buat gemini lewat bca") -> intent "transaction".
2) Selain itu (tanya saldo, minta saran, curhat, rencana/pengandaian seperti "kalau beli X", sapaan) -> intent "chat".
3) Jika jelas melaporkan transaksi tapi nominal tidak ada -> intent "chat" dan tanyakan nominalnya dengan santai.

Keluarkan HANYA JSON:
{"intent": "transaction" | "chat", "reply": string, "transaction": null | {"title": string, "amount": integer, "category": string, "type": "expense" | "income", "wallet": string | null}}

Aturan transaction:
- amount bilangan bulat rupiah ("25rb"->25000, "1,5jt"->1500000).
- title singkat & rapi tanpa nominal/nama dompet.
- category persis salah satu: ${categories.map((c) => '"$c"').join(', ')}.
- wallet persis salah satu dari ${wallets.map((w) => '"${w.name}"').join(', ')} sesuai metode bayar yang disebut. Jika tidak disebut isi null dan jangan mengarang atau memilih dompet yang tidak tersedia ("$defaultWallet").
- reply: konfirmasi natural bahwa transaksi sudah dicatat (sebut nominal & dompet dengan gaya santai, boleh komentar ringan). Jangan menyebut sisa saldo setelah transaksi.
''';

    // Riwayat obrolan (maks 10 terakhir). Gemini mewajibkan giliran pertama = user.
    final turns = history.length > 10
        ? history.sublist(history.length - 10)
        : history;
    final contents = <Map<String, dynamic>>[];
    for (final t in turns) {
      if (contents.isEmpty && !t.isUser) continue;
      contents.add({
        'role': t.isUser ? 'user' : 'model',
        'parts': [
          {'text': t.text},
        ],
      });
    }
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage},
      ],
    });

    final json = await _callJson(
      systemInstruction: system,
      contents: contents,
      temperature: 0.8,
    );

    if (json != null) {
      final reply = (json['reply'] ?? '').toString().trim();
      final txRaw = json['transaction'];
      if (json['intent'] == 'transaction' && txRaw is Map<String, dynamic>) {
        final tx = _normalize(txRaw, userMessage);
        if (tx != null) return AiChatResult(reply: reply, transaction: tx);
      }
      if (reply.isNotEmpty) return AiChatResult(reply: reply);
    }

    // ---- Fallback tanpa AI ----
    if (_looksLikeTransaction(userMessage)) {
      final tx = _localParse(userMessage);
      if (tx != null) return AiChatResult(reply: '', transaction: tx);
    }
    return AiChatResult(reply: _fallbackResponse(userMessage, totalBalance));
  }

  static String _fallbackResponse(String prompt, int balance) {
    final lower = prompt.toLowerCase();
    if (lower.contains('saldo') || lower.contains('sisa')) {
      return 'Total saldo kamu sekarang Rp $balance. Koneksi AI-nya lagi bermasalah, tapi data saldo tetap aman 👍';
    }
    return 'Maaf, aku lagi susah nyambung ke server AI. Coba kirim lagi sebentar lagi ya. Sementara itu, saldo kamu Rp $balance.';
  }

  /// Generates advice using the survival prediction and recent transaction pattern.
  static Future<String> generateFinancialAdvice(
    List<TransactionEntity> transactions, {
    required int currentBalance,
    required int dailySafeBudget,
    required int estimatedSurvivalDays,
    required int remainingDays,
    required bool isCritical,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final recentStart = today.subtract(const Duration(days: 13));
    final previousStart = today.subtract(const Duration(days: 27));
    final recentExpenses = transactions.where(
      (transaction) =>
          transaction.type == TransactionType.expense &&
          !transaction.date.isBefore(recentStart) &&
          !transaction.date.isAfter(now),
    );
    final previousExpenses = transactions.where(
      (transaction) =>
          transaction.type == TransactionType.expense &&
          !transaction.date.isBefore(previousStart) &&
          transaction.date.isBefore(recentStart),
    );
    final recentCategoryTotals = <String, int>{};
    var recentExpenseTotal = 0;
    var recentExpenseCount = 0;
    for (final transaction in recentExpenses) {
      recentExpenseTotal += transaction.amount;
      recentExpenseCount++;
      recentCategoryTotals.update(
        transaction.category,
        (total) => total + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    final previousExpenseTotal = previousExpenses.fold<int>(
      0,
      (total, transaction) => total + transaction.amount,
    );
    final topCategory = recentCategoryTotals.entries.isEmpty
        ? null
        : recentCategoryTotals.entries.reduce(
            (a, b) => a.value >= b.value ? a : b,
          );
    final recentDailyAverage = (recentExpenseTotal / 14).round();
    final previousDailyAverage = (previousExpenseTotal / 14).round();
    final spendingTrend = previousDailyAverage == 0
        ? 'Belum cukup data pada 14 hari sebelumnya untuk membandingkan tren.'
        : recentDailyAverage > previousDailyAverage
        ? 'Rata-rata pengeluaran 14 hari terakhir naik ${((recentDailyAverage - previousDailyAverage) / previousDailyAverage * 100).round()}% dibanding 14 hari sebelumnya.'
        : recentDailyAverage < previousDailyAverage
        ? 'Rata-rata pengeluaran 14 hari terakhir turun ${((previousDailyAverage - recentDailyAverage) / previousDailyAverage * 100).round()}% dibanding 14 hari sebelumnya.'
        : 'Rata-rata pengeluaran 14 hari terakhir stabil dibanding 14 hari sebelumnya.';
    final behaviorSummary = recentExpenseCount == 0
        ? 'Belum ada pengeluaran tercatat dalam 14 hari terakhir.'
        : '$recentExpenseCount transaksi pengeluaran dalam 14 hari terakhir, total Rp $recentExpenseTotal (rata-rata Rp $recentDailyAverage per hari). '
              '${topCategory == null ? '' : 'Kategori terbesar: ${topCategory.key} (Rp ${topCategory.value}).'} '
              '$spendingTrend';

    final status = isCritical
        ? 'KRITIS: saldo diproyeksikan bertahan $estimatedSurvivalDays hari, kurang dari $remainingDays hari tersisa di bulan ini.'
        : 'TERKENDALI: saldo diproyeksikan bertahan $estimatedSurvivalDays hari untuk $remainingDays hari tersisa di bulan ini.';
    final context =
        '''
Status survival mode: $status
Saldo saat ini: Rp $currentBalance
Batas aman belanja harian: Rp $dailySafeBudget
Perilaku transaksi terbaru: $behaviorSummary
''';
    final result = await _callJson(
      systemInstruction: '''
Kamu adalah Gemini Financial Advisor untuk aplikasi keuangan mahasiswa Indonesia.
Berikan satu saran singkat dan spesifik dalam bahasa Indonesia yang hangat, praktis, dan tidak menghakimi.
Sesuaikan urgensi dengan status survival mode. Jika KRITIS, jelaskan prioritas tindakan segera, sarankan menahan pengeluaran non-esensial, gunakan batas harian yang tersedia, dan arahkan saran ke pola/kategori belanja nyata bila ada. Jika TERKENDALI, beri penguatan sekaligus satu cara menjaga kebiasaan baik berdasarkan pola transaksi.
Gunakan hanya data yang diberikan. Jangan mengarang transaksi, tanggal pemasukan, atau komitmen tagihan. Jangan menjanjikan saldo akan cukup. Hindari nasihat investasi atau pinjaman.
Keluarkan JSON saja dengan format {"advice": "satu atau dua kalimat saran"}.
''',
      contents: [
        {
          'role': 'user',
          'parts': [
            {'text': context},
          ],
        },
      ],
      temperature: 0.4,
    );
    final advice = result?['advice'];
    if (advice is String && advice.trim().isNotEmpty) return advice.trim();

    if (isCritical) {
      final categoryAdvice = topCategory == null
          ? 'Belum ada kategori pengeluaran terbaru yang cukup jelas untuk diprioritaskan.'
          : 'Kategori ${topCategory.key} menjadi pengeluaran terbesar belakangan ini (Rp ${topCategory.value}), jadi cek dulu apakah ada bagian yang bisa ditunda.';
      return '⚠️ Saldo diproyeksikan bertahan $estimatedSurvivalDays hari, sementara masih ada $remainingDays hari di bulan ini. Usahakan pengeluaran harian tidak melebihi Rp $dailySafeBudget dan tahan dulu belanja non-esensial. $categoryAdvice $spendingTrend';
    }

    final trendAdvice = recentExpenseCount == 0
        ? 'Catat pengeluaran berikutnya agar perkiraan tetap relevan.'
        : topCategory == null
        ? 'Terus pantau transaksi harian agar pola belanja tetap terlihat.'
        : 'Pantau kategori ${topCategory.key}, yang paling besar dalam 14 hari terakhir (Rp ${topCategory.value}).';
    return '✅ Proyeksi saat ini terkendali untuk $remainingDays hari tersisa. Pertahankan pengeluaran di sekitar batas Rp $dailySafeBudget per hari. $trendAdvice $spendingTrend';
  }
}
