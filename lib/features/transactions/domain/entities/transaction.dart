import 'package:flutter/foundation.dart';

import 'transaction_category.dart';

export 'transaction_category.dart';

/// Satu catatan transaksi keuangan.
///
/// Immutable: perubahan dilakukan dengan membuat objek baru lewat [copyWith].
@immutable
class Transaction {
  const Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.recurringId,
    this.walletId,
    this.note = '',
    this.photoPath,
  }) : assert(amount > 0, 'Nominal harus lebih dari 0');

  final String id;

  /// Judul / deskripsi singkat, mis. "Belanja sayur".
  final String title;

  /// Nominal selalu positif; arah uang ditentukan oleh [type].
  final double amount;
  final TransactionType type;
  final TransactionCategory category;
  final DateTime date;

  /// ID [RecurringTransaction] bila transaksi ini dicatat dari transaksi
  /// rutin bulanan; `null` untuk transaksi biasa.
  final String? recurringId;

  bool get isRecurring => recurringId != null;

  /// Dompet asal/tujuan uang. `null` = dompet bawaan (data versi lama
  /// sebelum ada fitur dompet).
  final String? walletId;

  /// Catatan tambahan (opsional), mis. "Beli di pasar Kranji".
  final String note;

  /// Path file foto struk/nota di penyimpanan aplikasi (opsional).
  final String? photoPath;

  bool get isIncome => type == TransactionType.income;

  /// Nominal bertanda: positif untuk pemasukan, negatif untuk pengeluaran.
  double get signedAmount => isIncome ? amount : -amount;

  Transaction copyWith({
    String? title,
    double? amount,
    TransactionType? type,
    TransactionCategory? category,
    DateTime? date,
    String? walletId,
    String? note,
    // Fungsi agar foto bisa dihapus (dikembalikan ke null).
    String? Function()? photoPath,
  }) => Transaction(
    id: id,
    title: title ?? this.title,
    amount: amount ?? this.amount,
    type: type ?? this.type,
    category: category ?? this.category,
    date: date ?? this.date,
    recurringId: recurringId,
    walletId: walletId ?? this.walletId,
    note: note ?? this.note,
    photoPath: photoPath == null ? this.photoPath : photoPath(),
  );

  @override
  bool operator ==(Object other) =>
      other is Transaction &&
      other.id == id &&
      other.title == title &&
      other.amount == amount &&
      other.type == type &&
      other.category == category &&
      other.date == date &&
      other.recurringId == recurringId &&
      other.walletId == walletId &&
      other.note == note &&
      other.photoPath == photoPath;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    amount,
    type,
    category,
    date,
    recurringId,
    walletId,
    note,
    photoPath,
  );

  @override
  String toString() =>
      'Transaction($id, $title, $amount, ${type.name}, ${category.id}, $date)';
}
