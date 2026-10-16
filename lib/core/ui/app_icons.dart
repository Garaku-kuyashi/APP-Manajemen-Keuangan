import 'package:flutter/material.dart';

/// Satu sumber ikon untuk seluruh aplikasi supaya gaya konsisten:
/// semua memakai varian outlined (tidak aktif) dan filled (aktif).
class AppIcons {
  // Navigasi
  static const home = Icons.home_outlined;
  static const homeActive = Icons.home;
  static const wallet = Icons.account_balance_wallet_outlined;
  static const walletActive = Icons.account_balance_wallet;
  static const ai = Icons.auto_awesome_outlined;
  static const aiActive = Icons.auto_awesome;
  static const report = Icons.bar_chart_outlined;
  static const reportActive = Icons.bar_chart;
  static const profile = Icons.person_outline;
  static const profileActive = Icons.person;

  // Aksi
  static const add = Icons.add;
  static const edit = Icons.edit_outlined;
  static const delete = Icons.delete_outline;
  static const settings = Icons.settings_outlined;
  static const send = Icons.send_outlined;
  static const save = Icons.save_outlined;

  // Tipe transaksi: pemasukan = panah turun (uang masuk), pengeluaran = panah naik (uang keluar)
  static const income = Icons.arrow_downward;
  static const expense = Icons.arrow_upward;

  // Warna aksen
  static const Color aiColor = Colors.purpleAccent;
  static const Color incomeColor = Colors.green;
  static const Color expenseColor = Colors.red;
}
