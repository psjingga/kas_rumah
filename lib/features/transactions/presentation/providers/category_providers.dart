import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/transaction_category.dart';
import '../../domain/repositories/category_repository.dart';

/// Repository kategori buatan pengguna; di-override di `main()` / tes.
final categoryRepositoryProvider = Provider<CategoryRepository>(
  (ref) => throw UnimplementedError(
    'categoryRepositoryProvider harus di-override di ProviderScope',
  ),
);

/// Kategori buatan pengguna.
final customCategoriesProvider =
    NotifierProvider<CustomCategoriesNotifier, List<TransactionCategory>>(
      CustomCategoriesNotifier.new,
    );

/// Semua kategori: bawaan lalu buatan pengguna.
final allCategoriesProvider = Provider<List<TransactionCategory>>(
  (ref) => [
    ...TransactionCategory.builtIns,
    ...ref.watch(customCategoriesProvider),
  ],
);

/// Kategori untuk satu jenis transaksi (isi dropdown & chip filter).
final categoriesOfTypeProvider =
    Provider.family<List<TransactionCategory>, TransactionType>(
      (ref, type) => [
        for (final c in ref.watch(allCategoriesProvider))
          if (c.type == type) c,
      ],
    );

/// Peta ID → kategori terbaru. Dipakai untuk melengkapi kategori yang
/// dibaca dari Hive (yang hanya menyimpan ID).
final categoryLookupProvider = Provider<Map<String, TransactionCategory>>(
  (ref) => {for (final c in ref.watch(allCategoriesProvider)) c.id: c},
);

class CustomCategoriesNotifier extends Notifier<List<TransactionCategory>> {
  static const _uuid = Uuid();

  CategoryRepository get _repository => ref.read(categoryRepositoryProvider);

  @override
  List<TransactionCategory> build() =>
      ref.watch(categoryRepositoryProvider).getAll();

  Future<TransactionCategory> add({
    required String label,
    required TransactionType type,
    required String iconKey,
    required Color color,
  }) async {
    final category = TransactionCategory(
      id: 'c-${_uuid.v4()}',
      label: label.trim(),
      type: type,
      iconKey: iconKey,
      color: color,
    );
    await _repository.save(category);
    state = [...state, category];
    return category;
  }

  /// Ubah nama/ikon/warna. Transaksi lama otomatis ikut tampil dengan data
  /// terbaru karena transaksi hanya menyimpan ID kategori.
  Future<void> edit(TransactionCategory category) async {
    if (category.builtIn) {
      throw ArgumentError('Kategori bawaan tidak bisa diubah');
    }
    await _repository.save(category);
    state = [for (final c in state) c.id == category.id ? category : c];
  }

  Future<void> remove(String id) async {
    await _repository.delete(id);
    state = [
      for (final c in state)
        if (c.id != id) c,
    ];
  }
}
