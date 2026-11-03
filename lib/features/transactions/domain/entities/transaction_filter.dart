import 'package:flutter/foundation.dart';

import 'transaction.dart';

/// Kriteria pencarian riwayat transaksi. Semua kriteria digabung (AND);
/// kriteria kosong/`null` berarti "semua".
@immutable
class TransactionFilter {
  const TransactionFilter({this.query = '', this.type, this.category});

  /// Kata kunci: dicocokkan ke judul dan nama kategori (tanpa beda huruf
  /// besar/kecil). Angka juga dicocokkan ke nominal, mis. "450" → 450.000.
  final String query;
  final TransactionType? type;
  final TransactionCategory? category;

  bool get isEmpty => query.trim().isEmpty && type == null && category == null;

  bool matches(Transaction t) {
    if (type != null && t.type != type) return false;
    if (category != null && t.category != category) return false;

    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final digits = q.replaceAll(RegExp(r'[.\s]'), '');
    return t.title.toLowerCase().contains(q) ||
        t.category.label.toLowerCase().contains(q) ||
        (RegExp(r'^\d+$').hasMatch(digits) &&
            t.amount.toStringAsFixed(0).contains(digits));
  }

  List<Transaction> apply(Iterable<Transaction> transactions) =>
      transactions.where(matches).toList();

  /// Ganti jenis; kategori dilepas bila tidak cocok dengan jenis baru.
  TransactionFilter withType(TransactionType? type) => TransactionFilter(
    query: query,
    type: type,
    category: type == null || category?.type == type ? category : null,
  );

  TransactionFilter withQuery(String query) =>
      TransactionFilter(query: query, type: type, category: category);

  TransactionFilter withCategory(TransactionCategory? category) =>
      TransactionFilter(query: query, type: type, category: category);
}
