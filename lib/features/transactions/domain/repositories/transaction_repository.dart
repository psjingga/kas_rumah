import '../entities/transaction.dart';

/// Kontrak penyimpanan transaksi.
///
/// Lapisan presentation hanya mengenal kontrak ini, sehingga Hive bisa
/// diganti (mis. ke Isar atau API) tanpa menyentuh UI maupun Notifier.
abstract interface class TransactionRepository {
  /// Semua transaksi, terbaru lebih dulu.
  List<Transaction> getAll();

  /// Simpan transaksi baru atau timpa yang ber-ID sama.
  Future<void> save(Transaction transaction);

  Future<void> delete(String id);

  /// Ganti seluruh isi (dipakai saat memulihkan backup).
  Future<void> replaceAll(List<Transaction> transactions);
}
