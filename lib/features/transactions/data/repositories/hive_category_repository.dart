import 'dart:ui';

import 'package:hive_ce/hive_ce.dart';

import '../../domain/entities/transaction_category.dart';
import '../../domain/repositories/category_repository.dart';

/// Menyimpan kategori buatan pengguna sebagai list map di box `settings`.
class HiveCategoryRepository implements CategoryRepository {
  const HiveCategoryRepository(this._box);

  final Box<dynamic> _box;

  static const _key = 'custom_categories';

  static Map<String, Object> toMap(TransactionCategory c) => {
    'id': c.id,
    'label': c.label,
    'type': c.type.name,
    'iconKey': c.iconKey,
    'color': c.color.toARGB32(),
  };

  static TransactionCategory fromMap(Map<dynamic, dynamic> m) =>
      TransactionCategory(
        id: m['id'] as String,
        label: m['label'] as String,
        type: TransactionType.values.byName(m['type'] as String),
        iconKey: m['iconKey'] as String,
        color: Color(m['color'] as int),
      );

  @override
  List<TransactionCategory> getAll() => [
    for (final m
        in (_box.get(_key) as List?)?.whereType<Map<dynamic, dynamic>>() ??
            const <Map<dynamic, dynamic>>[])
      fromMap(m),
  ];

  @override
  Future<void> save(TransactionCategory category) => replaceAll([
    for (final c in getAll())
      if (c.id != category.id) c,
    category,
  ]);

  @override
  Future<void> delete(String id) => replaceAll([
    for (final c in getAll())
      if (c.id != id) c,
  ]);

  @override
  Future<void> replaceAll(List<TransactionCategory> categories) =>
      _box.put(_key, [for (final c in categories) toMap(c)]);
}
