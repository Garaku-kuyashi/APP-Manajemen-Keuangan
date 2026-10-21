import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/theme/app_colors.dart';
import '../../../../core/di/theme/theme_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final pageBackground = isDark
            ? AppColors.darkBackground
            : AppColors.lightBackground;
        final navigationColor = isDark
            ? AppColors.surface
            : AppColors.lightBackgroundCard;
        final cardColor = isDark
            ? AppColors.surface
            : AppColors.lightBackgroundCard;
        final primaryText = isDark
            ? AppColors.textPrimary
            : AppColors.primaryText;
        final secondaryText = isDark
            ? AppColors.textSecondary
            : AppColors.secondaryText;
        final borderColor = isDark
            ? AppColors.darkBorder
            : AppColors.lightBorder;

        final dividerColor = isDark ? AppColors.divider : AppColors.lightGray;

        return Scaffold(
          backgroundColor: pageBackground,
          appBar: AppBar(
            title: Text('Pengaturan', style: TextStyle(color: primaryText)),
            backgroundColor: navigationColor,
            foregroundColor: primaryText,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text(
                  'Tampilan',
                  style: TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: cardColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: borderColor, width: 1),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: Icon(
                      themeMode == ThemeMode.dark
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      color: AppColors.accentBlue,
                    ),
                    title: Text(
                      'Mode Gelap',
                      style: TextStyle(color: primaryText),
                    ),
                    subtitle: Text(
                      themeMode == ThemeMode.dark
                          ? 'Material 3 Dark Mode'
                          : 'Material 3 Light Mode',
                      style: TextStyle(color: secondaryText),
                    ),
                    trailing: Switch(
                      value: themeMode == ThemeMode.dark,
                      activeThumbColor: AppColors.accentBlue,
                      onChanged: (value) =>
                          context.read<ThemeCubit>().toggleTheme(value),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Tentang',
                  style: TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  color: cardColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: borderColor, width: 1),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.info_outline,
                          color: AppColors.accentBlue,
                        ),
                        title: Text(
                          'Versi Aplikasi',
                          style: TextStyle(color: primaryText),
                        ),
                        subtitle: Text(
                          'v1.0.0 • Clean Architecture (Feature-First)',
                          style: TextStyle(color: secondaryText),
                        ),
                      ),
                      Divider(height: 1, color: dividerColor),
                      ListTile(
                        leading: const Icon(
                          Icons.description_outlined,
                          color: AppColors.accentBlue,
                        ),
                        title: Text(
                          'Tentang MyMoney',
                          style: TextStyle(color: primaryText),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: secondaryText,
                        ),
                        onTap: () => showAboutDialog(
                          context: context,
                          applicationName: 'MyMoney',
                          applicationVersion: 'v1.0.0',
                          applicationLegalese: 'Aplikasi manajemen keuangan mahasiswa dengan asisten AI.',
                          applicationIcon: CircleAvatar(
                            backgroundColor: isDark
                                ? AppColors.darkLogoBackground
                                : AppColors.lightLogoBackground,
                            child: Icon(
                              Icons.account_balance_wallet_outlined,
                              color: isDark
                                  ? AppColors.textPrimary
                                  : AppColors.navyBlue,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
