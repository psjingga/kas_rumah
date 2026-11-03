import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Pengaturan kunci aplikasi. PIN tidak pernah disimpan apa adanya, hanya
/// hash SHA-256 dari `salt + PIN`.
@immutable
class SecuritySettings {
  const SecuritySettings({
    this.pinHash,
    this.salt,
    this.pinLength = 0,
    this.biometric = false,
  });

  final String? pinHash;
  final String? salt;

  /// Panjang PIN (4–6), agar layar kunci bisa langsung memeriksa begitu
  /// digit terakhir diketik.
  final int pinLength;

  /// Boleh membuka dengan sidik jari / wajah.
  final bool biometric;

  bool get hasPin => pinHash != null && salt != null;

  static const minPinLength = 4;
  static const maxPinLength = 6;

  /// Buat pengaturan baru dengan [pin] (salt acak).
  factory SecuritySettings.withPin(String pin, {bool biometric = false}) {
    final rnd = Random.secure();
    final salt = base64Url.encode(List.generate(16, (_) => rnd.nextInt(256)));
    return SecuritySettings(
      pinHash: hashPin(pin, salt),
      salt: salt,
      pinLength: pin.length,
      biometric: biometric,
    );
  }

  static String hashPin(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  bool verify(String pin) => hasPin && hashPin(pin, salt!) == pinHash;

  SecuritySettings copyWith({bool? biometric}) => SecuritySettings(
    pinHash: pinHash,
    salt: salt,
    pinLength: pinLength,
    biometric: biometric ?? this.biometric,
  );
}

/// Kontrak penyimpanan [SecuritySettings].
abstract interface class SecurityRepository {
  SecuritySettings load();

  Future<void> save(SecuritySettings settings);
}

/// Kontrak autentikasi biometrik (sidik jari / wajah).
abstract interface class BiometricAuth {
  Future<bool> isAvailable();

  Future<bool> authenticate(String reason);
}
