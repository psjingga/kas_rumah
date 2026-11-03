import '../../../core/utils/formatters.dart';
import '../../transactions/domain/entities/transaction.dart';

/// Tingkat pemakaian anggaran.
enum BudgetLevel {
  /// < 80%.
  safe,

  /// 80% s/d < 100%.
  warning,

  /// ≥ 100%.
  over;

  static const warningRatio = .8;

  static BudgetLevel of(double ratio) => ratio >= 1
      ? over
      : ratio >= warningRatio
      ? warning
      : safe;
}

/// Pemakaian anggaran satu kategori dalam satu bulan.
class BudgetStatus {
  const BudgetStatus({
    required this.category,
    required this.limit,
    required this.spent,
  });

  final TransactionCategory category;

  /// Batas pengeluaran per bulan.
  final double limit;
  final double spent;

  double get ratio => limit <= 0 ? 0 : spent / limit;
  double get remaining => limit - spent;
  BudgetLevel get level => BudgetLevel.of(ratio);
}

/// Hitung status semua anggaran ([limits]: ID kategori → batas) dari
/// transaksi satu bulan. Urut dari pemakaian (%) tertinggi.
List<BudgetStatus> budgetStatuses({
  required Map<String, double> limits,
  required Map<String, TransactionCategory> categories,
  required Iterable<Transaction> monthTransactions,
}) {
  final spent = <String, double>{};
  for (final t in monthTransactions) {
    if (!t.isIncome) {
      spent[t.category.id] = (spent[t.category.id] ?? 0) + t.amount;
    }
  }
  return [
    for (final MapEntry(key: id, value: limit) in limits.entries)
      if (categories[id] case final category?)
        BudgetStatus(category: category, limit: limit, spent: spent[id] ?? 0),
  ]..sort((a, b) => b.ratio.compareTo(a.ratio));
}

/// Notifikasi peringatan anggaran yang perlu dikirim.
class BudgetAlert {
  const BudgetAlert({
    required this.key,
    required this.title,
    required this.body,
  });

  /// Kunci unik (bulan + kategori + tingkat) agar tiap peringatan hanya
  /// dikirim sekali.
  final String key;
  final String title;
  final String body;
}

/// Peringatan yang belum pernah dikirim ([sentKeys]) untuk [month].
/// Bila kategori langsung melewati 100%, hanya peringatan "terlampaui"
/// yang dikirim.
List<BudgetAlert> pendingBudgetAlerts({
  required List<BudgetStatus> statuses,
  required DateTime month,
  required Set<String> sentKeys,
}) {
  final prefix = '${month.year}-${month.month}';
  return [
    for (final s in statuses)
      if (s.level != BudgetLevel.safe)
        if ('$prefix|${s.category.id}|${s.level.name}' case final key
            when !sentKeys.contains(key))
          BudgetAlert(
            key: key,
            title: s.level == BudgetLevel.over
                ? 'Anggaran ${s.category.label} terlampaui'
                : 'Anggaran ${s.category.label} hampir habis',
            body: s.level == BudgetLevel.over
                ? 'Terpakai ${Fmt.rupiah(s.spent)} dari ${Fmt.rupiah(s.limit)}'
                      '${s.remaining < 0 ? ' (lebih ${Fmt.rupiah(-s.remaining)})' : ''}.'
                : 'Terpakai ${(s.ratio * 100).round()}% '
                      '(${Fmt.rupiah(s.spent)} dari ${Fmt.rupiah(s.limit)}). '
                      'Sisa ${Fmt.rupiah(s.remaining)}.',
          ),
  ];
}
