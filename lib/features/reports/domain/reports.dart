import '../../../core/utils/month.dart';
import '../../transactions/domain/entities/finance_summary.dart';
import '../../transactions/domain/entities/transaction.dart';

/// Total satu bulan dalam laporan tahunan.
typedef MonthRow = ({DateTime month, double income, double expense});

/// Rekap satu tahun: per bulan, total, kategori terbesar, bulan paling boros.
class YearReport {
  const YearReport({
    required this.year,
    required this.months,
    required this.expenseByCategory,
  });

  factory YearReport.from(Iterable<Transaction> transactions, int year) {
    final income = List.filled(12, 0.0);
    final expense = List.filled(12, 0.0);
    final byCategory = <TransactionCategory, double>{};
    for (final t in transactions) {
      if (t.date.year != year) continue;
      final i = t.date.month - 1;
      if (t.isIncome) {
        income[i] += t.amount;
      } else {
        expense[i] += t.amount;
        byCategory[t.category] = (byCategory[t.category] ?? 0) + t.amount;
      }
    }
    final sorted = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return YearReport(
      year: year,
      months: [
        for (var i = 0; i < 12; i++)
          (
            month: DateTime(year, i + 1),
            income: income[i],
            expense: expense[i],
          ),
      ],
      expenseByCategory: Map.fromEntries(sorted),
    );
  }

  final int year;

  /// Januari s/d Desember.
  final List<MonthRow> months;

  /// Pengeluaran per kategori setahun, urut terbesar.
  final Map<TransactionCategory, double> expenseByCategory;

  double get totalIncome => months.fold(0, (s, m) => s + m.income);
  double get totalExpense => months.fold(0, (s, m) => s + m.expense);
  double get net => totalIncome - totalExpense;

  /// Bulan yang punya transaksi.
  List<MonthRow> get activeMonths => [
    for (final m in months)
      if (m.income > 0 || m.expense > 0) m,
  ];

  /// Rata-rata pengeluaran per bulan, dihitung dari bulan yang ada datanya
  /// (agar tidak "turun" bila aplikasi baru dipakai di tengah tahun).
  double get averageMonthlyExpense {
    final active = activeMonths;
    return active.isEmpty ? 0 : totalExpense / active.length;
  }

  /// Persentase pemasukan yang tersisa (tidak dibelanjakan), 0..1; bisa
  /// negatif bila pengeluaran melebihi pemasukan.
  double get savingsRate => totalIncome == 0 ? 0 : net / totalIncome;

  /// Bulan dengan pengeluaran terbesar (`null` bila belum ada).
  MonthRow? get busiestMonth {
    MonthRow? best;
    for (final m in months) {
      if (m.expense > 0 && (best == null || m.expense > best.expense)) {
        best = m;
      }
    }
    return best;
  }

  double shareOf(TransactionCategory c) =>
      totalExpense == 0 ? 0 : (expenseByCategory[c] ?? 0) / totalExpense;
}

/// Satu baris perbandingan kategori antar-dua bulan.
typedef CategoryComparison = ({
  TransactionCategory category,
  double first,
  double second,
});

/// Perbandingan dua bulan: total & pengeluaran per kategori.
class MonthComparison {
  const MonthComparison({
    required this.first,
    required this.second,
    required this.firstSummary,
    required this.secondSummary,
    required this.rows,
  });

  factory MonthComparison.from(
    Iterable<Transaction> transactions,
    DateTime first,
    DateTime second,
  ) {
    final a = FinanceSummary.from(
      transactions.where((t) => t.date.isSameMonthAs(first)),
    );
    final b = FinanceSummary.from(
      transactions.where((t) => t.date.isSameMonthAs(second)),
    );
    final categories = {
      ...a.expenseByCategory.keys,
      ...b.expenseByCategory.keys,
    };
    final rows =
        [
          for (final c in categories)
            (
              category: c,
              first: a.expenseByCategory[c] ?? 0,
              second: b.expenseByCategory[c] ?? 0,
            ),
        ]..sort(
          (x, y) => (y.first > y.second ? y.first : y.second).compareTo(
            x.first > x.second ? x.first : x.second,
          ),
        );
    return MonthComparison(
      first: first.firstOfMonth,
      second: second.firstOfMonth,
      firstSummary: a,
      secondSummary: b,
      rows: rows,
    );
  }

  final DateTime first;
  final DateTime second;
  final FinanceSummary firstSummary;
  final FinanceSummary secondSummary;

  /// Pengeluaran per kategori di kedua bulan, urut nominal terbesar.
  final List<CategoryComparison> rows;
}
