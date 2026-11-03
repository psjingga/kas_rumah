import 'package:flutter/material.dart';

/// Warna teks/ikon untuk uang masuk, uang keluar, dan peringatan.
///
/// Di mode gelap memakai versi lebih terang agar tetap kontras dengan latar
/// gelap (hijau/merah tua sulit dibaca di atas latar hitam).
extension MoneyColors on BuildContext {
  bool get _dark => Theme.of(this).brightness == Brightness.dark;

  Color get incomeColor =>
      _dark ? const Color(0xFF81C784) : const Color(0xFF2E7D32);
  Color get expenseColor =>
      _dark ? const Color(0xFFEF9A9A) : const Color(0xFFD32F2F);
  Color get warningColor =>
      _dark ? const Color(0xFFFFB74D) : const Color(0xFFE65100);
}

/// Warna isian grafik (batang/irisan), cukup kontras di kedua mode.
abstract final class ChartColors {
  static const income = Color(0xFF43A047);
  static const expense = Color(0xFFE53935);
}
