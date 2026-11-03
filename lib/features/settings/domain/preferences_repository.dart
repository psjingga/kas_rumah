import 'package:flutter/material.dart';

/// Preferensi umum aplikasi.
abstract interface class PreferencesRepository {
  ThemeMode get themeMode;

  Future<void> setThemeMode(ThemeMode mode);

  /// Waktu backup terakhir dibuat; `null` bila belum pernah.
  DateTime? get lastBackupAt;

  Future<void> setLastBackupAt(DateTime time);

  /// Halaman pembuka sudah dilewati/diselesaikan.
  bool get onboardingDone;

  Future<void> setOnboardingDone();
}
