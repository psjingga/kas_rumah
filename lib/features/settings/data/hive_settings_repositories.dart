import 'package:flutter/material.dart';
import 'package:hive_ce/hive_ce.dart';

import '../domain/preferences_repository.dart';
import '../domain/security.dart';

/// Preferensi di box `settings`.
class HivePreferencesRepository implements PreferencesRepository {
  const HivePreferencesRepository(this._box);

  final Box<dynamic> _box;

  @override
  ThemeMode get themeMode => ThemeMode.values.firstWhere(
    (m) => m.name == _box.get('theme_mode'),
    orElse: () => ThemeMode.system,
  );

  @override
  Future<void> setThemeMode(ThemeMode mode) =>
      _box.put('theme_mode', mode.name);

  @override
  DateTime? get lastBackupAt => switch (_box.get('last_backup')) {
    final int ms => DateTime.fromMillisecondsSinceEpoch(ms),
    _ => null,
  };

  @override
  Future<void> setLastBackupAt(DateTime time) =>
      _box.put('last_backup', time.millisecondsSinceEpoch);

  @override
  bool get onboardingDone => _box.get('onboarding_done') == true;

  @override
  Future<void> setOnboardingDone() => _box.put('onboarding_done', true);
}

/// Pengaturan keamanan di box `settings`.
class HiveSecurityRepository implements SecurityRepository {
  const HiveSecurityRepository(this._box);

  final Box<dynamic> _box;

  static const _key = 'security';

  @override
  SecuritySettings load() {
    final m = _box.get(_key);
    if (m is! Map) return const SecuritySettings();
    return SecuritySettings(
      pinHash: m['pinHash'] as String?,
      salt: m['salt'] as String?,
      pinLength: m['pinLength'] as int? ?? 0,
      biometric: m['biometric'] as bool? ?? false,
    );
  }

  @override
  Future<void> save(SecuritySettings s) => _box.put(_key, {
    'pinHash': s.pinHash,
    'salt': s.salt,
    'pinLength': s.pinLength,
    'biometric': s.biometric,
  });
}
