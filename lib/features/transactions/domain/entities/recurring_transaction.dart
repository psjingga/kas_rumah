import 'package:flutter/foundation.dart';

import '../../../../core/utils/month.dart';
import 'transaction.dart';

/// Transaksi rutin bulanan, mis. gaji tiap tanggal 25 atau listrik tiap
/// tanggal 5.
///
/// Ini hanya **template**: setiap bulan template muncul sebagai "belum
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
  }) : assert(amount > 0, 'Nominal harus lebih dari 0'),
       assert(dayOfMonth >= 1 && dayOfMonth <= 31, 'Tanggal 1–31');

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

  bool get isIncome => type == TransactionType.income;

  /// Apakah template ini harus dicatat di [month].
  bool appliesTo(DateTime month) =>
      active && !month.firstOfMonth.isBefore(startMonth.firstOfMonth);

  /// Tanggal jatuh tempo di [month], mis. tanggal 31 → 30 November.
  DateTime dueDate(DateTime month) =>
      DateTime(month.year, month.month, dayOfMonth.clamp(1, month.daysInMonth));

  RecurringTransaction copyWith({
    String? title,
    double? amount,
    TransactionType? type,
    TransactionCategory? category,
    int? dayOfMonth,
    DateTime? startMonth,
    bool? active,
    String? walletId,
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
      other.walletId == walletId;

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
  );
}
