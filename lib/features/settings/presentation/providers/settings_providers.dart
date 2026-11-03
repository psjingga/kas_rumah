import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../transactions/presentation/providers/recurring_providers.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../domain/preferences_repository.dart';
import '../../domain/security.dart';

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => throw UnimplementedError(
    'preferencesRepositoryProvider harus di-override di ProviderScope',
  ),
);

final securityRepositoryProvider = Provider<SecurityRepository>(
  (ref) => throw UnimplementedError(
    'securityRepositoryProvider harus di-override di ProviderScope',
  ),
);

final biometricAuthProvider = Provider<BiometricAuth>(
  (ref) => throw UnimplementedError(
    'biometricAuthProvider harus di-override di ProviderScope',
  ),
);

/// Tema: ikuti sistem / terang / gelap.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Waktu backup terakhir.
final lastBackupProvider = NotifierProvider<LastBackupNotifier, DateTime?>(
  LastBackupNotifier.new,
);

/// `false` = tampilkan halaman pembuka. Pengguna yang sudah punya data
/// (versi sebelum ada halaman pembuka) dianggap sudah selesai.
final onboardingDoneProvider = NotifierProvider<OnboardingNotifier, bool>(
  OnboardingNotifier.new,
);

/// Pengaturan kunci aplikasi (PIN & biometrik).
final securityProvider = NotifierProvider<SecurityNotifier, SecuritySettings>(
  SecurityNotifier.new,
);

/// `true` selama aplikasi terkunci dan menunggu PIN/biometrik.
final appLockedProvider = NotifierProvider<AppLockNotifier, bool>(
  AppLockNotifier.new,
);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(preferencesRepositoryProvider).themeMode;

  Future<void> set(ThemeMode mode) async {
    await ref.read(preferencesRepositoryProvider).setThemeMode(mode);
    state = mode;
  }
}

class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.read(preferencesRepositoryProvider).onboardingDone ||
      ref.read(transactionRepositoryProvider).getAll().isNotEmpty ||
      ref.read(recurringRepositoryProvider).getAll().isNotEmpty;

  Future<void> complete() async {
    await ref.read(preferencesRepositoryProvider).setOnboardingDone();
    state = true;
  }
}

class LastBackupNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => ref.watch(preferencesRepositoryProvider).lastBackupAt;

  Future<void> markNow() async {
    final now = ref.read(clockProvider)();
    await ref.read(preferencesRepositoryProvider).setLastBackupAt(now);
    state = now;
  }
}

class SecurityNotifier extends Notifier<SecuritySettings> {
  @override
  SecuritySettings build() => ref.watch(securityRepositoryProvider).load();

  Future<void> _save(SecuritySettings s) async {
    await ref.read(securityRepositoryProvider).save(s);
    state = s;
  }

  Future<void> setPin(String pin) =>
      _save(SecuritySettings.withPin(pin, biometric: state.biometric));

  /// Matikan kunci aplikasi (hapus PIN).
  Future<void> removePin() => _save(const SecuritySettings());

  Future<void> setBiometric(bool on) => _save(state.copyWith(biometric: on));
}

class AppLockNotifier extends Notifier<bool> {
  /// Terkunci lagi bila aplikasi di latar belakang selama ini.
  static const lockAfter = Duration(seconds: 30);

  DateTime? _backgroundSince;

  /// Terkunci saat aplikasi dibuka bila PIN sudah diatur.
  @override
  bool build() => ref.read(securityProvider).hasPin;

  bool unlockWithPin(String pin) {
    final ok = ref.read(securityProvider).verify(pin);
    if (ok) state = false;
    return ok;
  }

  Future<bool> unlockWithBiometric() async {
    final ok = await ref
        .read(biometricAuthProvider)
        .authenticate('Buka Kas Rumah');
    if (ok) state = false;
    return ok;
  }

  void onBackground() => _backgroundSince ??= ref.read(clockProvider)();

  void onForeground() {
    final since = _backgroundSince;
    _backgroundSince = null;
    if (since == null || !ref.read(securityProvider).hasPin) return;
    if (ref.read(clockProvider)().difference(since) >= lockAfter) state = true;
  }
}
