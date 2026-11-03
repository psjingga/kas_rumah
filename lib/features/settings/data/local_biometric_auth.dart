import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../domain/security.dart';

/// [BiometricAuth] berbasis package local_auth.
class LocalBiometricAuth implements BiometricAuth {
  final _auth = LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported() &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (e) {
      debugPrint('Biometrik tidak tersedia: $e');
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } catch (e) {
      debugPrint('Autentikasi biometrik gagal: $e');
      return false;
    }
  }
}
