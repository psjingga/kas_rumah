import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/month.dart';
import '../../../transactions/presentation/providers/category_providers.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../domain/budget.dart';
import '../../domain/budget_repository.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => throw UnimplementedError(
    'budgetRepositoryProvider harus di-override di ProviderScope',
  ),
);

/// ID kategori → batas pengeluaran per bulan.
final budgetLimitsProvider =
    NotifierProvider<BudgetLimitsNotifier, Map<String, double>>(
      BudgetLimitsNotifier.new,
    );

/// Status anggaran di bulan terpilih (urut % pemakaian tertinggi).
final budgetStatusProvider = Provider<List<BudgetStatus>>(
  (ref) => budgetStatuses(
    limits: ref.watch(budgetLimitsProvider),
    categories: ref.watch(categoryLookupProvider),
    monthTransactions: ref.watch(monthTransactionsProvider),
  ),
);

/// Status anggaran bulan **berjalan** (bukan bulan yang sedang dilihat),
/// untuk peringatan otomatis.
final currentBudgetStatusProvider = Provider<List<BudgetStatus>>((ref) {
  final month = ref.read(clockProvider)().firstOfMonth;
  return budgetStatuses(
    limits: ref.watch(budgetLimitsProvider),
    categories: ref.watch(categoryLookupProvider),
    monthTransactions: ref
        .watch(transactionsProvider)
        .where((t) => t.date.isSameMonthAs(month)),
  );
});

class BudgetLimitsNotifier extends Notifier<Map<String, double>> {
  BudgetRepository get _repository => ref.read(budgetRepositoryProvider);

  @override
  Map<String, double> build() =>
      ref.watch(budgetRepositoryProvider).getLimits();

  /// Atur batas kategori [categoryId]; `null`/≤0 menghapus anggarannya.
  Future<void> setLimit(String categoryId, double? limit) async {
    final next = {...state}..remove(categoryId);
    if (limit != null && limit > 0) next[categoryId] = limit;
    await _repository.replaceLimits(next);
    state = next;
  }
}
