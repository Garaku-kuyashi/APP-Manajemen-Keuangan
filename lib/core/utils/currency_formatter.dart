import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat _formatterWithoutSymbol =
      NumberFormat.decimalPattern('id_ID');

  static String format(num amount) {
    return _formatter.format(amount);
  }

  static String formatWithoutSymbol(num amount) {
    return _formatterWithoutSymbol.format(amount);
  }

  static int? parseRupiahAmount(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }
}
