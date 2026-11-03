import '../entities/transaction_category.dart';

/// Kontrak penyimpanan kategori buatan pengguna (kategori bawaan tidak
/// disimpan karena sudah ada di kode).
abstract interface class CategoryRepository {
  List<TransactionCategory> getAll();

  Future<void> save(TransactionCategory category);

  Future<void> delete(String id);

  /// Ganti seluruh isi (dipakai saat memulihkan backup).
  Future<void> replaceAll(List<TransactionCategory> categories);
}
