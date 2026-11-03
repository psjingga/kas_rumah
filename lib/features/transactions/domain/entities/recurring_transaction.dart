import 'package:flutter/material.dart' show DateUtils, immutable;

import '../../../../core/utils/month.dart';
import 'transaction.dart';

/// Frekuensi transaksi rutin.
enum RecurrenceFrequency {
  weekly('Mingguan'),
  monthly('Bulanan'),
  yearly('Tahunan');

  const RecurrenceFrequency(this.label);

  final String label;
}

/// Satu jatuh tempo transaksi rutin, mis. "Cicilan motor ke-3, 5 Jan".
typedef RecurringOccurrence = ({
  RecurringTransaction recurring,
  DateTime date,

  /// Urutan kemunculan (1 = pertama).
  int number,
});

const _weekdays = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// Transaksi rutin: mingguan (mis. uang jajan tiap Senin), bulanan (gaji
/// tiap tgl 25, listrik tiap tgl 5), atau tahunan (pajak motor tiap 15 Mar).
/// Bisa berupa **cicilan** yang berhenti sendiri setelah [totalOccurrences]
/// kali.
///
/// Ini hanya **template**: setiap jatuh tempo muncul sebagai "belum
/// dicatat" sampai pengguna mencatatnya menjadi [Transaction] (nominalnya
/// boleh berbeda dari [amount] bawaan). Transaksi hasil catatan menyimpan
/// [id] template di `Transaction.recurringId`.
@immutable
class RecurringTransaction {
  const RecurringTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.dayOfMonth,
    required this.startMonth,
    this.active = true,
    this.walletId,
    this.frequency = RecurrenceFrequency.monthly,
    this.weekday = DateTime.monday,
    this.monthOfYear = 1,
    this.totalOccurrences,
  }) : assert(amount > 0, 'Nominal harus lebih dari 0'),
       assert(dayOfMonth >= 1 && dayOfMonth <= 31, 'Tanggal 1–31'),
       assert(weekday >= 1 && weekday <= 7, 'Hari 1–7'),
       assert(monthOfYear >= 1 && monthOfYear <= 12, 'Bulan 1–12'),
       assert(totalOccurrences == null || totalOccurrences > 0);

  final String id;
  final String title;

  /// Nominal default tiap bulan.
  final double amount;
  final TransactionType type;
  final TransactionCategory category;

  /// Tanggal jatuh tempo tiap bulan (1–31). Untuk bulan yang lebih pendek,
  /// dipakai tanggal terakhir bulan tersebut.
  final int dayOfMonth;

  /// Bulan pertama template berlaku; bulan sebelumnya tidak ditagih.
  final DateTime startMonth;

  /// Template nonaktif tidak muncul sebagai tagihan bulanan.
  final bool active;

  /// Dompet yang dipakai saat dicatat; `null` = dompet bawaan.
  final String? walletId;

  final RecurrenceFrequency frequency;

  /// Hari untuk frekuensi mingguan ([DateTime.monday]..[DateTime.sunday]).
  final int weekday;

  /// Bulan untuk frekuensi tahunan (1–12); tanggalnya [dayOfMonth].
  final int monthOfYear;

  /// Jumlah kali bayar untuk cicilan (mis. 12); `null` = tanpa akhir.
  final int? totalOccurrences;

  bool get isIncome => type == TransactionType.income;
  bool get isInstallment => totalOccurrences != null;

  /// "Tiap tgl 5", "Tiap Senin", atau "Tiap 15 Mar".
  String get scheduleLabel => switch (frequency) {
    RecurrenceFrequency.weekly => 'Tiap ${_weekdays[weekday - 1]}',
    RecurrenceFrequency.monthly => 'Tiap tgl $dayOfMonth',
    RecurrenceFrequency.yearly =>
      'Tiap $dayOfMonth ${_months[monthOfYear - 1]}',
  };

  static String weekdayName(int weekday) => _weekdays[weekday - 1];
  static String monthName(int month) => _months[month - 1];

  /// Tanggal jatuh tempo di [month] (bulanan/tahunan), mis. tanggal 31 →
  /// 30 November.
  DateTime dueDate(DateTime month) =>
      DateTime(month.year, month.month, dayOfMonth.clamp(1, month.daysInMonth));

  /// Jatuh tempo pertama sejak [startMonth].
  DateTime get _first => switch (frequency) {
    RecurrenceFrequency.monthly => dueDate(startMonth),
    RecurrenceFrequency.yearly => dueDate(
      DateTime(
        startMonth.month <= monthOfYear ? startMonth.year : startMonth.year + 1,
        monthOfYear,
      ),
    ),
    RecurrenceFrequency.weekly => startMonth.firstOfMonth.add(
      Duration(days: (weekday - startMonth.firstOfMonth.weekday) % 7),
    ),
  };

  /// Jatuh tempo ke-[n] (1 = pertama).
  DateTime nth(int n) => switch (frequency) {
    RecurrenceFrequency.monthly => dueDate(startMonth.addMonths(n - 1)),
    RecurrenceFrequency.yearly => dueDate(
      DateTime(_first.year + n - 1, monthOfYear),
    ),
    RecurrenceFrequency.weekly => DateTime(
      _first.year,
      _first.month,
      _first.day + 7 * (n - 1),
    ),
  };

  /// Urutan jatuh tempo pada tanggal [date] (1 = pertama).
  int occurrenceNumber(DateTime date) => switch (frequency) {
    RecurrenceFrequency.monthly =>
      (date.year - startMonth.year) * 12 + date.month - startMonth.month + 1,
    RecurrenceFrequency.yearly => date.year - _first.year + 1,
    RecurrenceFrequency.weekly =>
      DateUtils.dateOnly(date).difference(_first).inDays ~/ 7 + 1,
  };

  /// Nominal setara per bulan (mingguan ×52/12, tahunan ÷12), untuk total
  /// rutin bulanan.
  double get monthlyEquivalent => switch (frequency) {
    RecurrenceFrequency.weekly => amount * 52 / 12,
    RecurrenceFrequency.monthly => amount,
    RecurrenceFrequency.yearly => amount / 12,
  };

  /// Jatuh tempo terakhir cicilan; `null` bila tanpa akhir.
  DateTime? get lastOccurrence =>
      totalOccurrences == null ? null : nth(totalOccurrences!);

  /// Semua jatuh tempo di bulan kalender [month] (bisa lebih dari satu
  /// untuk mingguan). Kosong bila nonaktif, belum mulai, atau cicilan sudah
  /// habis.
  List<RecurringOccurrence> occurrencesIn(DateTime month) {
    final m = month.firstOfMonth;
    if (!active || m.isBefore(startMonth.firstOfMonth)) return const [];
    final dates = switch (frequency) {
      RecurrenceFrequency.monthly => [dueDate(m)],
      RecurrenceFrequency.yearly =>
        m.month == monthOfYear ? [dueDate(m)] : const <DateTime>[],
      RecurrenceFrequency.weekly => [
        for (var d = 1; d <= m.daysInMonth; d++)
          if (DateTime(m.year, m.month, d) case final date
              when date.weekday == weekday && !date.isBefore(_first))
            date,
      ],
    };
    return [
      for (final d in dates)
        if (occurrenceNumber(d) case final n
            when totalOccurrences == null || n <= totalOccurrences!)
          (recurring: this, date: d, number: n),
    ];
  }

  /// Apakah template ini punya jatuh tempo di [month].
  bool appliesTo(DateTime month) => occurrencesIn(month).isNotEmpty;

  /// Dua tanggal dianggap satu periode tagihan: minggu yang sama (Senin–
  /// Minggu) untuk mingguan, bulan yang sama untuk bulanan/tahunan. Dipakai
  /// agar transaksi yang dicatat lebih awal/lambat tetap terhitung.
  bool samePeriod(DateTime a, DateTime b) =>
      frequency == RecurrenceFrequency.weekly
      ? _weekStart(a) == _weekStart(b)
      : a.isSameMonthAs(b);

  static DateTime _weekStart(DateTime d) {
    final day = DateUtils.dateOnly(d);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  /// Sudah dicatat untuk jatuh tempo [date]?
  bool isRecordedIn(Iterable<Transaction> transactions, DateTime date) =>
      transactions.any((t) => t.recurringId == id && samePeriod(t.date, date));

  /// Jumlah transaksi yang sudah dicatat dari template ini.
  int recordedCount(Iterable<Transaction> transactions) =>
      transactions.where((t) => t.recurringId == id).length;

  RecurringTransaction copyWith({
    String? title,
    double? amount,
    TransactionType? type,
    TransactionCategory? category,
    int? dayOfMonth,
    DateTime? startMonth,
    bool? active,
    String? walletId,
    RecurrenceFrequency? frequency,
    int? weekday,
    int? monthOfYear,
    // Fungsi agar cicilan bisa diubah menjadi tanpa akhir (null).
    int? Function()? totalOccurrences,
  }) => RecurringTransaction(
    id: id,
    title: title ?? this.title,
    amount: amount ?? this.amount,
    type: type ?? this.type,
    category: category ?? this.category,
    dayOfMonth: dayOfMonth ?? this.dayOfMonth,
    startMonth: startMonth ?? this.startMonth,
    active: active ?? this.active,
    walletId: walletId ?? this.walletId,
    frequency: frequency ?? this.frequency,
    weekday: weekday ?? this.weekday,
    monthOfYear: monthOfYear ?? this.monthOfYear,
    totalOccurrences: totalOccurrences == null
        ? this.totalOccurrences
        : totalOccurrences(),
  );

  @override
  bool operator ==(Object other) =>
      other is RecurringTransaction &&
      other.id == id &&
      other.title == title &&
      other.amount == amount &&
      other.type == type &&
      other.category == category &&
      other.dayOfMonth == dayOfMonth &&
      other.startMonth == startMonth &&
      other.active == active &&
      other.walletId == walletId &&
      other.frequency == frequency &&
      other.weekday == weekday &&
      other.monthOfYear == monthOfYear &&
      other.totalOccurrences == totalOccurrences;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    amount,
    type,
    category,
    dayOfMonth,
    startMonth,
    active,
    walletId,
    frequency,
    weekday,
    monthOfYear,
    totalOccurrences,
  );
}
