import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/recurring_transaction.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/recurring_repository.dart';
import 'category_providers.dart';
import 'transaction_providers.dart';

/// Repository template transaksi rutin; di-override di `main()` / tes.
final recurringRepositoryProvider = Provider<RecurringRepository>(
  (ref) => throw UnimplementedError(
    'recurringRepositoryProvider harus di-override di ProviderScope',
  ),
);

/// Semua template transaksi rutin bulanan.
final recurringProvider =
    NotifierProvider<RecurringNotifier, List<RecurringTransaction>>(
      RecurringNotifier.new,
    );

/// Transaksi rutin yang berlaku di bulan terpilih tetapi **belum dicatat**.
///
/// Begitu dicatat (ada transaksi dengan `recurringId` yang sama di bulan
/// itu), item hilang dari daftar ini. Bila transaksinya dihapus, item
/// muncul lagi.
final pendingRecurringProvider = Provider<List<RecurringOccurrence>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  final transactions = ref.watch(transactionsProvider);
  return [
    for (final r in ref.watch(recurringProvider))
      for (final o in r.occurrencesIn(month))
        if (!r.isRecordedIn(transactions, o.date)) o,
  ]..sort((a, b) => a.date.compareTo(b.date));
});

class RecurringNotifier extends Notifier<List<RecurringTransaction>> {
  static const _uuid = Uuid();

  RecurringRepository get _repository => ref.read(recurringRepositoryProvider);

  /// Kategori dilengkapi dari daftar kategori terbaru (lihat
  /// `TransactionsNotifier.build`).
  @override
  List<RecurringTransaction> build() {
    final lookup = ref.watch(categoryLookupProvider);
    return [
      for (final r in ref.watch(recurringRepositoryProvider).getAll())
        r.copyWith(
          category:
              lookup[r.category.id] ??
              TransactionCategory.byId(r.category.id, r.type),
        ),
    ];
  }

  Future<RecurringTransaction> add({
    required String title,
    required double amount,
    required TransactionType type,
    required TransactionCategory category,
    required int dayOfMonth,
    required DateTime startMonth,
    String? walletId,
    RecurrenceFrequency frequency = RecurrenceFrequency.monthly,
    int weekday = DateTime.monday,
    int monthOfYear = 1,
    int? totalOccurrences,
  }) async {
    final recurring = RecurringTransaction(
      id: _uuid.v4(),
      title: title.trim(),
      amount: amount,
      type: type,
      category: category,
      dayOfMonth: dayOfMonth,
      startMonth: startMonth,
      walletId: walletId,
      frequency: frequency,
      weekday: weekday,
      monthOfYear: monthOfYear,
      totalOccurrences: totalOccurrences,
    );
    await save(recurring);
    return recurring;
  }

  /// Simpan template baru atau perubahan template (mis. nominal default
  /// baru, nonaktifkan). Transaksi yang sudah tercatat tidak ikut berubah.
  Future<void> save(RecurringTransaction recurring) async {
    if (recurring.category.type != recurring.type) {
      throw ArgumentError.value(recurring.category, 'category');
    }
    await _repository.save(recurring);
    state = _sorted([recurring, ...state.where((r) => r.id != recurring.id)]);
  }

  Future<void> remove(String id) async {
    await _repository.delete(id);
    state = [
      for (final r in state)
        if (r.id != id) r,
    ];
  }

  static List<RecurringTransaction> _sorted(List<RecurringTransaction> list) =>
      list..sort((a, b) => a.dayOfMonth.compareTo(b.dayOfMonth));
}
