import '../../features/wallet/domain/entities/wallet_entity.dart';

/// Mencocokkan teks bebas (dari input user / hasil AI) ke dompet yang ada.
/// Tidak bergantung pada nama persis, jadi "bca", "m-bca", "transfer",
/// "gopay", "gojek", "tunai", dst. tetap terbaca.
class WalletMatcher {
  static const Map<String, List<String>> _aliases = {
    'gopay': ['gopay', 'go-pay', 'go pay', 'gojek', 'ovo', 'dana', 'shopeepay'],
    'bca': ['bca', 'm-bca', 'mbca', 'bank', 'rekening', 'atm', 'debit'],
    'cash': ['cash', 'tunai', 'kontan', 'uang cash'],
  };

  static String _key(WalletEntity w) {
    final n = w.name.toLowerCase();
    for (final k in _aliases.keys) {
      if (n.contains(k)) return k;
    }
    return n;
  }

  /// Cari dompet dari [text]. Mengembalikan null jika tidak ada petunjuk.
  static WalletEntity? find(String? text, List<WalletEntity> wallets) {
    if (text == null || text.trim().isEmpty || wallets.isEmpty) return null;
    final lower = text.toLowerCase();

    // 1) nama dompet disebut langsung
    for (final w in wallets) {
      if (lower.contains(w.name.toLowerCase())) return w;
    }
    // 2) lewat alias
    for (final w in wallets) {
      final aliases = _aliases[_key(w)] ?? const <String>[];
      for (final a in aliases) {
        if (RegExp('(^|[^a-z])${RegExp.escape(a)}([^a-z]|\$)').hasMatch(lower)) {
          return w;
        }
      }
    }
    return null;
  }

  /// Dompet bawaan jika user tidak menyebut metode pembayaran.
  static WalletEntity fallback(List<WalletEntity> wallets) => wallets.first;
}
