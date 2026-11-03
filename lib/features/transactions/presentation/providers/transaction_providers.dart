import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/month.dart';
import '../../domain/entities/finance_summary.dart';
import '../../domain/entities/recurring_transaction.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import 'category_providers.dart';

/// Repository transaksi. Nilainya diisi di `main()` lewat
/// `ProviderScope(overrides: ...)` setelah box Hive terbuka; di tes
/// diganti repository palsu.
final transactionRepositoryProvider = Provider<TransactionRepository>(
  (ref) => throw UnimplementedError(
    'transactionRepositoryProvider harus di-override di ProviderScope',
  ),
);

/// Sumber waktu "sekarang". Di tes di-override agar "bulan ini" tetap.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Bulan yang sedang ditampilkan di dashboard (tanggal 1 bulan tsb).
final selectedMonthProvider = NotifierProvider<SelectedMonthNotifier, DateTime>(
  SelectedMonthNotifier.new,
);

/// Semua transaksi (terbaru lebih dulu) beserta aksi tambah/ubah/hapus.
final transactionsProvider =
    NotifierProvider<TransactionsNotifier, List<Transaction>>(
      TransactionsNotifier.new,
    );

/// Transaksi di bulan terpilih saja.
final monthTransactionsProvider = Provider<List<Transaction>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  return [
    for (final t in ref.watch(transactionsProvider))
      if (t.date.isSameMonthAs(month)) t,
  ];
});

/// Sisa saldo (pemasukan − pengeluaran) bulan sebelum bulan terpilih.
final previousMonthBalanceProvider = Provider<double>((ref) {
  final previous = ref.watch(selectedMonthProvider).addMonths(-1);
  return ref
      .watch(transactionsProvider)
      .where((t) => t.date.isSameMonthAs(previous))
      .fold(0.0, (sum, t) => sum + t.signedAmount);
});

/// Ringkasan bulan terpilih (total pemasukan, pengeluaran, saldo, per
/// kategori, plus sisa bulan lalu sebagai informasi). Otomatis dihitung
/// ulang bila transaksi atau bulan berubah.
final financeSummaryProvider = Provider<FinanceSummary>(
  (ref) => FinanceSummary.from(
    ref.watch(monthTransactionsProvider),
    previousMonthBalance: ref.watch(previousMonthBalanceProvider),
  ),
);

/// Total pemasukan & pengeluaran satu bulan, untuk grafik tren.
typedef MonthTotals = ({DateTime month, double income, double expense});

/// Tren 6 bulan terakhir, diakhiri bulan terpilih (urut lama → baru).
final monthlyTrendProvider = Provider<List<MonthTotals>>((ref) {
  const count = 6;
  final last = ref.watch(selectedMonthProvider);
  final first = last.addMonths(-(count - 1));
  final income = <DateTime, double>{};
  final expense = <DateTime, double>{};

  for (final t in ref.watch(transactionsProvider)) {
    final m = t.date.firstOfMonth;
    if (m.isBefore(first) || m.isAfter(last)) continue;
    final bucket = t.isIncome ? income : expense;
    bucket[m] = (bucket[m] ?? 0) + t.amount;
  }

  return [
    for (var i = 0; i < count; i++)
      (
        month: first.addMonths(i),
        income: income[first.addMonths(i)] ?? 0,
        expense: expense[first.addMonths(i)] ?? 0,
      ),
  ];
});

/// Shortcut bila widget hanya butuh satu angka; widget tersebut tidak ikut
/// rebuild ketika angka lain berubah.
final totalIncomeProvider = Provider<double>(
  (ref) => ref.watch(financeSummaryProvider).totalIncome,
);
final totalExpenseProvider = Provider<double>(
  (ref) => ref.watch(financeSummaryProvider).totalExpense,
);
final balanceProvider = Provider<double>(
  (ref) => ref.watch(financeSummaryProvider).balance,
);

class SelectedMonthNotifier extends Notifier<DateTime> {
  DateTime get _thisMonth => ref.read(clockProvider)().firstOfMonth;

  @override
  DateTime build() => _thisMonth;

  void previous() => state = state.addMonths(-1);
  void next() => state = state.addMonths(1);
  void goToThisMonth() => state = _thisMonth;
  void select(DateTime month) => state = month.firstOfMonth;

  bool get isThisMonth => state == _thisMonth;
}

class TransactionsNotifier extends Notifier<List<Transaction>> {
  static const _uuid = Uuid();

  TransactionRepository get _repository =>
      ref.read(transactionRepositoryProvider);

  /// State awal dibaca langsung dari Hive (sinkron, box sudah terbuka).
  /// Kategori dilengkapi dari daftar kategori terbaru (Hive hanya menyimpan
  /// ID-nya), jadi ikut berubah bila kategori diganti nama/warna.
  @override
  List<Transaction> build() {
    final lookup = ref.watch(categoryLookupProvider);
    return [
      for (final t in ref.watch(transactionRepositoryProvider).getAll())
        t.copyWith(
          category:
              lookup[t.category.id] ??
              TransactionCategory.byId(t.category.id, t.type),
        ),
    ];
  }

  /// Tambah transaksi baru. Data disimpan ke Hive dulu, baru state diubah,
  /// sehingga UI tidak pernah menampilkan data yang gagal tersimpan.
  Future<Transaction> add({
    required String title,
    required double amount,
    required TransactionType type,
    required TransactionCategory category,
    required DateTime date,
    String? recurringId,
  }) async {
    _validate(amount, type, category);
    final transaction = Transaction(
      id: _uuid.v4(),
      title: title.trim(),
      amount: amount,
      type: type,
      category: category,
      date: date,
      recurringId: recurringId,
    );
    await _repository.save(transaction);
    state = _sorted([transaction, ...state]);
    return transaction;
  }

  /// Simpan perubahan transaksi yang sudah ada (ID sama).
  Future<void> edit(Transaction transaction) async {
    _validate(transaction.amount, transaction.type, transaction.category);
    await _repository.save(transaction);
    state = _sorted([
      for (final t in state) t.id == transaction.id ? transaction : t,
    ]);
  }

  /// Catat transaksi rutin [recurring] untuk [month]. Nominal memakai
  /// default template kecuali [amount] diisi (nominal khusus bulan ini).
  ///
  /// Bila sudah tercatat di bulan itu, transaksi yang ada dikembalikan
  /// (tidak dobel).
  Future<Transaction> recordRecurring(
    RecurringTransaction recurring,
    DateTime month, {
    double? amount,
  }) async {
    final existing = state
        .where(
          (t) => t.recurringId == recurring.id && t.date.isSameMonthAs(month),
        )
        .firstOrNull;
    if (existing != null) return existing;

    return add(
      title: recurring.title,
      amount: amount ?? recurring.amount,
      type: recurring.type,
      category: recurring.category,
      date: recurring.dueDate(month),
      recurringId: recurring.id,
    );
  }

  /// Catat semua [recurring] untuk [month] dengan nominal default.
  Future<void> recordAllRecurring(
    Iterable<RecurringTransaction> recurring,
    DateTime month,
  ) async {
    for (final r in recurring) {
      await recordRecurring(r, month);
    }
  }

  /// Hapus transaksi berdasarkan [id]. Mengembalikan transaksi yang
  /// terhapus (untuk fitur "Urungkan"), atau `null` jika tidak ada.
  ///
  /// Berbeda dengan [add], state diubah lebih dulu (optimistic) karena
  /// `Dismissible` mewajibkan item langsung hilang dari list; bila Hive
  /// gagal, state dikembalikan.
  Future<Transaction?> remove(String id) async {
    final before = state;
    final target = before.where((t) => t.id == id).firstOrNull;
    if (target == null) return null;

    state = [
      for (final t in before)
        if (t.id != id) t,
    ];
    try {
      await _repository.delete(id);
    } catch (_) {
      state = before;
      rethrow;
    }
    return target;
  }

  /// Kembalikan transaksi yang baru dihapus (aksi "Urungkan").
  Future<void> restore(Transaction transaction) async {
    await _repository.save(transaction);
    state = _sorted([
      transaction,
      ...state.where((t) => t.id != transaction.id),
    ]);
  }

  static void _validate(
    double amount,
    TransactionType type,
    TransactionCategory category,
  ) {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'harus lebih dari 0');
    }
    if (category.type != type) {
      throw ArgumentError.value(
        category,
        'category',
        'bukan kategori ${type.label.toLowerCase()}',
      );
    }
  }

  static List<Transaction> _sorted(List<Transaction> list) =>
      list..sort((a, b) => b.date.compareTo(a.date));
}
