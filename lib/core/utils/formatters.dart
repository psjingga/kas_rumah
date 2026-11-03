import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Format angka & tanggal dalam gaya Indonesia.
abstract final class Fmt {
  static final _rupiah = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  static final _ribuan = NumberFormat.decimalPattern('id_ID');
  static final _ringkas = NumberFormat.compact(locale: 'id_ID');

  /// 1500000 → "Rp 1.500.000"; nilai negatif → "-Rp 85.000".
  static String rupiah(double value) =>
      value < 0 ? '-${_rupiah.format(-value)}' : _rupiah.format(value);

  /// Ringkas untuk sumbu grafik: 1500000 → "1,5 jt", 250000 → "250 rb".
  static String compact(double value) => _ringkas.format(value);

  /// "Sen, 4 Nov 2026 · 08.00".
  static String dateTime(DateTime d) =>
      DateFormat("EEE, d MMM yyyy '·' HH.mm", 'id_ID').format(d);

  /// Judul grup harian: "Hari ini", "Kemarin", atau "Senin, 2 Nov".
  static String dayHeader(DateTime d, DateTime now) {
    final day = DateTime(d.year, d.month, d.day);
    final today = DateTime(now.year, now.month, now.day);
    return switch (today.difference(day).inDays) {
      0 => 'Hari ini',
      1 => 'Kemarin',
      _ => DateFormat(
        d.year == now.year ? 'EEEE, d MMM' : 'EEEE, d MMM yyyy',
        'id_ID',
      ).format(d),
    };
  }

  /// Perubahan persen dari [before] ke [after]: "▲12%" / "▼5%"; `null`
  /// bila tidak bisa dibandingkan ([before] 0).
  static String? change(double before, double after) {
    if (before <= 0) return null;
    final pct = ((after - before) / before * 100).round();
    if (pct == 0) return '=0%';
    return pct > 0 ? '▲$pct%' : '▼${-pct}%';
  }

  /// Dengan tanda: 250000 → "+Rp 250.000", -85000 → "−Rp 85.000".
  static String signed(double value) =>
      value >= 0 ? '+${rupiah(value)}' : '−${rupiah(-value)}';

  /// "Nov" (nama bulan singkat).
  static String shortMonth(DateTime d) => DateFormat('MMM', 'id_ID').format(d);

  /// 1500000 → "1.500.000" (untuk isi field nominal).
  static String thousands(num value) => _ribuan.format(value);

  /// "1.500.000" → 1500000. `null` jika teks bukan angka.
  static double? parseAmount(String text) {
    final digits = text.replaceAll('.', '').replaceAll(' ', '');
    return digits.isEmpty ? null : double.tryParse(digits);
  }

  /// "3 Nov 2026". Perlu `initializeDateFormatting('id_ID')` di `main()`.
  static String date(DateTime d) => DateFormat('d MMM yyyy', 'id_ID').format(d);

  /// "November 2026".
  static String month(DateTime d) => DateFormat('MMMM yyyy', 'id_ID').format(d);
}

/// Formatter field nominal: hanya menerima digit dan otomatis memberi
/// pemisah ribuan ("1500000" → "1.500.000") saat mengetik.
class ThousandsInputFormatter extends TextInputFormatter {
  const ThousandsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();
    // Batasi 15 digit (ratusan triliun) agar tetap presisi sebagai double.
    if (digits.length > 15) return oldValue;

    final formatted = Fmt.thousands(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
