import '../entities/recurring_transaction.dart';

/// Kontrak penyimpanan template transaksi rutin bulanan.
abstract interface class RecurringRepository {
  /// Semua template, urut tanggal jatuh tempo.
  List<RecurringTransaction> getAll();

  /// Simpan template baru atau timpa yang ber-ID sama.
  Future<void> save(RecurringTransaction recurring);

  Future<void> delete(String id);

  /// Ganti seluruh isi (dipakai saat memulihkan backup).
  Future<void> replaceAll(List<RecurringTransaction> recurring);
}
