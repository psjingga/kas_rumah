import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/presentation/pages/app_lock.dart';
import '../features/settings/presentation/providers/settings_providers.dart';
import 'home_shell.dart';

/// Navigator utama, agar notifikasi yang diketuk bisa membuka halaman dari
/// luar pohon widget (lihat `main.dart`).
final appNavigatorKey = GlobalKey<NavigatorState>();

const _seed = Color(0xFF00796B);

ThemeData _theme(Brightness brightness) => ThemeData(
  colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
  inputDecorationTheme: const InputDecorationTheme(
    border: OutlineInputBorder(),
  ),
  cardTheme: const CardThemeData(margin: EdgeInsets.zero),
);

class KeuanganApp extends ConsumerWidget {
  const KeuanganApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Kas Rumah',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ref.watch(themeModeProvider),
      // Bahasa Indonesia untuk date picker & teks bawaan Material.
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Layar kunci PIN menutupi seluruh halaman (termasuk dialog).
      builder: (context, child) => AppLockGate(child: child!),
      home: const HomeShell(),
    );
  }
}
