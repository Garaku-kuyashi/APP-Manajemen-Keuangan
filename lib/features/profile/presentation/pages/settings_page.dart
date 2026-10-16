import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/theme/theme_cubit.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Tampilan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Card(
              child: BlocBuilder<ThemeCubit, ThemeMode>(
                builder: (context, themeMode) {
                  final isDark = themeMode == ThemeMode.dark;
                  return ListTile(
                    leading: Icon(isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
                    title: const Text('Mode Gelap'),
                    subtitle: Text(isDark ? 'Material 3 Dark Mode' : 'Material 3 Light Mode'),
                    trailing: Switch(
                      value: isDark,
                      onChanged: (val) => context.read<ThemeCubit>().toggleTheme(val),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            const Text('Tentang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Versi Aplikasi'),
                    subtitle: Text('v1.0.0 • Clean Architecture (Feature-First)'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Tentang MyMoney'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: 'MyMoney',
                      applicationVersion: 'v1.0.0',
                      applicationLegalese: 'Aplikasi manajemen keuangan mahasiswa dengan asisten AI.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
