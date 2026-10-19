import 'package:flutter/material.dart';

abstract final class AppColors {
  // Warna identitas
  static const Color navyBlue = Color(0xFF0D235E);
  static const Color accentBlue = Color(0xFF3A83F9);
  static const Color lightGray = Color(0xFFDDE1E5);

  // Background dan surface
  static const Color background = Color(0xFF1C1C1C);
  static const Color surface = Color(0xFF262626);
  static const Color divider = Color(0xFF373737);
  static const Color lightBorder = Color(0xFFDDE1E5);
  static const Color darkBorder = Color(0xFF575757);

  // Status transaksi
  static const Color positive = Color(0xFF1DD58D);
  static const Color negative = Color(0xFFFF7A85);

  // Light mode
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightBackgroundCard = Color(0xFFFFFFFF);
  static const Color lightNavigation = Color(0xFFEAF5FF);
  static const Color lightInputBackground = Color(0xFFD1E8FF);

  // Dark mode
  static const Color darkBackground = Color(0xFF08090D);
  static const Color darkNavigation = Color(0xFF0A1216);

  // Teks untuk light mode
  static const Color primaryText = Color(0xFF15171C);
  static const Color secondaryText = Color(0xFF595F66);

  // Teks untuk dark mode
  static const Color textPrimary = Color(0xFFE3E3E3);
  static const Color textSecondary = Color(0xFFA8A8A8);

  // Logo
  static const Color lightLogoBackground = Color(0xFFE4F3F9);
  static const Color darkLogoBackground = Color(0xFF262626);
}
