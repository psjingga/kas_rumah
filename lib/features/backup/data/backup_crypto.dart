import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// Kata sandi backup salah (atau file sudah diubah).
class WrongPasswordException implements Exception {
  const WrongPasswordException();

  @override
  String toString() => 'Kata sandi salah atau file backup rusak.';
}

/// Enkripsi file backup dengan kata sandi.
///
/// Kunci 256-bit diturunkan dari kata sandi dengan PBKDF2-HMAC-SHA256 (salt
/// acak), lalu isi backup dienkripsi AES-256-GCM. GCM sekaligus memeriksa
/// keaslian: kata sandi salah atau isi diubah → [WrongPasswordException].
class BackupCrypto {
  const BackupCrypto({this.iterations = 150000});

  /// Jumlah iterasi PBKDF2 (makin besar makin tahan tebakan, makin lambat).
  final int iterations;

  static const _app = 'keuangan_rumah_tangga';

  /// Data tambahan yang ikut diautentikasi (bukan rahasia).
  static final _aad = utf8.encode('kas-rumah-backup-v1');

  /// Apakah [text] berupa backup terenkripsi.
  static bool isEncrypted(String text) {
    try {
      final m = jsonDecode(text);
      return m is Map && m['app'] == _app && m['encrypted'] == true;
    } on FormatException {
      return false;
    }
  }

  static List<int> _random(int n) {
    final rnd = Random.secure();
    return List.generate(n, (_) => rnd.nextInt(256));
  }

  Future<SecretKey> _key(String password, List<int> salt, int iterations) =>
      Pbkdf2.hmacSha256(
        iterations: iterations,
        bits: 256,
      ).deriveKeyFromPassword(password: password, nonce: salt);

  /// Enkripsi [plainJson] (isi backup) dengan [password].
  Future<String> encrypt(String plainJson, String password) async {
    final salt = _random(16);
    final key = await _key(password, salt, iterations);
    final box = await AesGcm.with256bits().encrypt(
      utf8.encode(plainJson),
      secretKey: key,
      nonce: _random(12),
      aad: _aad,
    );
    return const JsonEncoder.withIndent(' ').convert({
      'app': _app,
      'encrypted': true,
      'kdf': 'pbkdf2-hmac-sha256',
      'iterations': iterations,
      'salt': base64.encode(salt),
      'nonce': base64.encode(box.nonce),
      'mac': base64.encode(box.mac.bytes),
      'data': base64.encode(box.cipherText),
    });
  }

  /// Buka backup terenkripsi; kembalikan isi backup (JSON biasa).
  Future<String> decrypt(String envelope, String password) async {
    final Map<dynamic, dynamic> m;
    try {
      m = jsonDecode(envelope) as Map;
    } on Object {
      throw const FormatException('File bukan backup yang valid.');
    }
    if (m['encrypted'] != true || m['kdf'] != 'pbkdf2-hmac-sha256') {
      throw const FormatException('Format enkripsi tidak dikenal.');
    }
    final key = await _key(
      password,
      base64.decode(m['salt'] as String),
      m['iterations'] as int,
    );
    try {
      final clear = await AesGcm.with256bits().decrypt(
        SecretBox(
          base64.decode(m['data'] as String),
          nonce: base64.decode(m['nonce'] as String),
          mac: Mac(base64.decode(m['mac'] as String)),
        ),
        secretKey: key,
        aad: _aad,
      );
      return utf8.decode(clear);
    } on SecretBoxAuthenticationError {
      throw const WrongPasswordException();
    }
  }
}
