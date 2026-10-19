import 'package:flutter/material.dart';
import 'package:mymoney/core/di/theme/app_colors.dart';

/// Palet warna dashboard yang mengikuti brightness tema aplikasi.
class DashboardColors {
  final bool isDark;
  final Color background;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color track;
  final Color popupBackground;
  final List<Color> balanceGradient;
  final Color navigationBar;

  const DashboardColors({
    required this.isDark,
    required this.background,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.track,
    required this.popupBackground,
    required this.balanceGradient,
    required this.navigationBar,
  });

  factory DashboardColors.from(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DashboardColors(
      isDark: isDark,
      background: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      card: isDark ? AppColors.surface : AppColors.lightBackgroundCard,
      border: isDark ? AppColors.darkBorder : AppColors.lightBorder,
      textPrimary: isDark ? AppColors.textPrimary : AppColors.primaryText,
      textSecondary: isDark ? AppColors.textSecondary : AppColors.secondaryText,
      track: isDark ? AppColors.divider : AppColors.lightNavigation,
      popupBackground: isDark ? AppColors.surface : AppColors.lightBackground,
      balanceGradient: const [
        AppColors.darkBackground,
        AppColors.navyBlue,
        AppColors.darkNavigation,
      ],
      navigationBar: isDark ? AppColors.surface : AppColors.lightNavigation,
    );
  }
}

/// Menjaga warna komponen dashboard selaras dengan mode terang/gelap aplikasi.
ThemeData dashboardThemeOf(BuildContext context, DashboardColors colors) {
  final base = Theme.of(context);
  final brightness = base.brightness;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.accentBlue,
    brightness: brightness,
    surface: colors.card,
  ).copyWith(
    primary: AppColors.accentBlue,
    onPrimary: Colors.white,
    surface: colors.card,
    onSurface: colors.textPrimary,
    onSurfaceVariant: colors.textSecondary,
  );

  return base.copyWith(
    brightness: brightness,
    scaffoldBackgroundColor: colors.background,
    canvasColor: colors.background,
    colorScheme: colorScheme,
    textTheme: base.textTheme.apply(
      bodyColor: colors.textPrimary,
      displayColor: colors.textPrimary,
    ),
    iconTheme: IconThemeData(color: colors.textPrimary),
    popupMenuTheme: PopupMenuThemeData(
      color: colors.popupBackground,
      surfaceTintColor: Colors.transparent,
    ),
    dividerColor: colors.border,
    bottomAppBarTheme: BottomAppBarThemeData(
      color: colors.card,
      surfaceTintColor: Colors.transparent,
    ),
  );
}
