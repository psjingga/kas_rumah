import 'package:hive_ce/hive_ce.dart';

import '../../domain/entities/recurring_transaction.dart';
import '../../domain/repositories/recurring_repository.dart';

/// Implementasi [RecurringRepository] di atas box Hive (key = ID template).
class HiveRecurringRepository implements RecurringRepository {
  const HiveRecurringRepository(this._box);

  final Box<RecurringTransaction> _box;

  @override
  List<RecurringTransaction> getAll() =>
      _box.values.toList()
        ..sort((a, b) => a.dayOfMonth.compareTo(b.dayOfMonth));

  @override
  Future<void> save(RecurringTransaction recurring) =>
      _box.put(recurring.id, recurring);

  @override
  Future<void> delete(String id) => _box.delete(id);

  @override
  Future<void> replaceAll(List<RecurringTransaction> recurring) async {
    await _box.clear();
    await _box.putAll({for (final r in recurring) r.id: r});
  }
}
