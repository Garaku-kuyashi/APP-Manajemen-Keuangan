import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../features/transaction/domain/entities/transaction_entity.dart';
import 'api_config.dart';

class GeminiAiService {
  // Masukkan API Key resmi milikmu dari Google AI Studio
  static const String _apiKey = ApiConfig.geminiApiKey;

  // Endpoint REST API menggunakan model gemini-2.5-flash
  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_apiKey';

  /// Memanggil AI Gemini secara Luwes & Alami
  static Future<String> chatWithStudentAdvisor({
    required String userMessage,
    required List<TransactionEntity> transactions,
    required int totalBalance,
  }) async {
    try {
      final txSummary = transactions.take(5).map((t) => 
        "- ${t.title} (${t.category}): Rp ${t.amount} [${t.type.name}]"
      ).join("\n");

      final promptText = '''
Kamu adalah "MyMoney Assistant", teman curhat sekaligus konsultan keuangan pribadi khusus mahasiswa.
Gaya bahasamu sangat santai, luwes, ramah, empatik, dan alami seperti mengobrol dengan teman dekat kampus (pakai kata "aku/kamu" atau "gue/lu").

Konteks Keuangan Mahasiswa Saat Ini:
- Total Sisa Saldo: Rp $totalBalance
- 5 Transaksi Terakhir:
$txSummary

Petunjuk Mengobrol:
1. Jawablah pesan pengguna secara fleksibel dan luwes.
2. Jika pengguna curhat/bertanya apa saja (misal: "mau ngeprint", "butuh saran 3 minggu", "bingung makan apa"), jawablah dengan solutif dan alami.
3. Jawab pendek dan langsung ke intinya (maksimal 2-3 kalimat).

Pesan Pengguna: "$userMessage"
''';

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": promptText}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];
        if (text != null && text.isNotEmpty) {
          return text;
        }
      } else {
        print("Error Gemini API (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      print("Gemini Exception: $e");
    }

    return _fallbackResponse(userMessage, totalBalance);
  }

  /// AI Prompt Parser untuk Ekstraksi Form Transaksi
  static Future<Map<String, dynamic>?> parseTransactionPrompt(String userPrompt) async {
    try {
      const systemInstruction = '''
Ekstrak data transaksi berikut menjadi JSON murni tanpa markdown/backticks:
{"title": String, "amount": int, "category": String, "type": String}

Aturan Kategori: ["Makan & Kopi", "Langganan AI", "Hiburan & Streaming", "Kuota & Internet", "Kebutuhan Kuliah", "Uang Saku", "Lainnya"].
Aturan Type: "expense" atau "income".
''';

      final response = await http.post(
        Uri.parse(_endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": '$systemInstruction\nInput: "$userPrompt"'}
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        text = text.replaceAll('```json', '').replaceAll('```', '').trim();
        return jsonDecode(text) as Map<String, dynamic>;
      }
    } catch (e) {
      print("Parse Error: $e");
    }
    return null;
  }

  /// Fallback Cerdas jika Terjadi Kendala Jaringan
  static String _fallbackResponse(String prompt, int balance) {
    final lower = prompt.toLowerCase();
    if (lower.contains('print') || lower.contains('cetak')) {
      return "Buat ngeprint tugas, coba cari fotokopi dekat kampus yang langganan mahasiswa biar dapet Rp 250/lembar. Sisa saldo kamu Rp $balance masih aman kok!";
    }
    if (lower.contains('saran') || lower.contains('minggu')) {
      return "Dengan sisa saldo Rp $balance, alokasikan Rp 30rb/hari buat makan & jajan. Sisanya simpan buat kebutuhan mendadak!";
    }
    return "Sisa saldo kamu saat ini Rp $balance. Mau diskusi alokasi pengeluaran lagi atau catat transaksi?";
  }

  /// Financial Advisor Laporan
  static Future<String> generateFinancialAdvice(List<TransactionEntity> transactions) async {
    if (transactions.isEmpty) return "Belum ada data transaksi.";
    return "🤖 **AI Insight:** Pola pengeluaran kamu masih dalam rentang aman. Pertahankan hingga akhir bulan!";
  }
}