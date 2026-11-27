import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Warna teks/ikon untuk uang masuk, uang keluar, dan peringatan — diambil
/// dari [AppPalette] (versi terang di mode gelap agar tetap kontras).
extension MoneyColors on BuildContext {
  Color get incomeColor => palette.income;
  Color get expenseColor => palette.expense;
  Color get warningColor => palette.warning;
}

/// Warna isian grafik (batang/irisan), cukup kontras di kedua mode.
abstract final class ChartColors {
  static const income = Color(0xFF2F9E6B);
  static const expense = Color(0xFFD9534F);
}
