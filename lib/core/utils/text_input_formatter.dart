import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class RupiahInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.decimalPattern('id_ID');
  final RegExp _nonDigit = RegExp(r'[^0-9]');
  final RegExp _digit = RegExp(r'[0-9]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cursorPosition = newValue.selection.extentOffset
        .clamp(0, newValue.text.length)
        .toInt();
    final digitsBeforeCursor = newValue.text
        .substring(0, cursorPosition)
        .replaceAll(_nonDigit, '')
        .length;

    final digits = newValue.text.replaceAll(_nonDigit, '');

    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final number = int.tryParse(digits);
    if (number == null) return oldValue;

    final formatted = _formatter.format(number);

    var caretOffset = 0;
    var countedDigits = 0;
    while (caretOffset < formatted.length &&
        countedDigits < digitsBeforeCursor) {
      if (_digit.hasMatch(formatted[caretOffset])) {
        countedDigits++;
      }
      caretOffset++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: caretOffset),
    );
  }
}
