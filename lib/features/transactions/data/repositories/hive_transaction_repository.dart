import 'package:hive_ce/hive_ce.dart';

import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';

/// Implementasi [TransactionRepository] di atas satu box Hive.
///
/// Key box = ID transaksi, sehingga hapus/timpa cukup lewat ID.
class HiveTransactionRepository implements TransactionRepository {
  const HiveTransactionRepository(this._box);

  final Box<Transaction> _box;

  @override
  List<Transaction> getAll() =>
      _box.values.toList()..sort((a, b) => b.date.compareTo(a.date));

  @override
  Future<void> save(Transaction transaction) =>
      _box.put(transaction.id, transaction);

  @override
  Future<void> delete(String id) => _box.delete(id);

  @override
  Future<void> replaceAll(List<Transaction> transactions) async {
    await _box.clear();
    await _box.putAll({for (final t in transactions) t.id: t});
  }
}
