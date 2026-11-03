/// Utilitas bulan. Sebuah "bulan" direpresentasikan sebagai [DateTime]
/// tanggal 1 pukul 00:00 (mis. `DateTime(2026, 11)`).
extension MonthX on DateTime {
  /// Tanggal 1 di bulan yang sama.
  DateTime get firstOfMonth => DateTime(year, month);

  /// Bulan ini ditambah [n] bulan (boleh negatif); `DateTime` menangani
  /// pergantian tahun, mis. Desember + 1 → Januari tahun berikutnya.
  DateTime addMonths(int n) => DateTime(year, month + n);

  bool isSameMonthAs(DateTime other) =>
      year == other.year && month == other.month;

  /// Jumlah hari di bulan ini (28–31).
  int get daysInMonth => DateTime(year, month + 1, 0).day;
}
