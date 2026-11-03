import 'transaction.dart';

/// Ringkasan keuangan yang dihitung dari daftar transaksi.
///
/// Murni (tanpa Flutter/Hive), sehingga mudah diuji.
class FinanceSummary {
  const FinanceSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.expenseByCategory,
    this.previousMonthBalance = 0,
  });

  /// Hitung ringkasan dari [transactions] dalam satu kali iterasi.
  ///
  /// [previousMonthBalance] = sisa saldo bulan sebelumnya (informasi saja).
  factory FinanceSummary.from(
    Iterable<Transaction> transactions, {
    double previousMonthBalance = 0,
  }) {
    var income = 0.0;
    var expense = 0.0;
    final byCategory = <TransactionCategory, double>{};

    for (final t in transactions) {
      switch (t.type) {
        case TransactionType.income:
          income += t.amount;
        case TransactionType.expense:
          expense += t.amount;
          byCategory.update(
            t.category,
            (total) => total + t.amount,
            ifAbsent: () => t.amount,
          );
      }
    }

    // Urutkan dari pengeluaran terbesar agar pie chart & legenda konsisten.
    final sorted = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return FinanceSummary(
      totalIncome: income,
      totalExpense: expense,
      expenseByCategory: Map.fromEntries(sorted),
      previousMonthBalance: previousMonthBalance,
    );
  }

  static const empty = FinanceSummary(
    totalIncome: 0,
    totalExpense: 0,
    expenseByCategory: {},
  );

  final double totalIncome;
  final double totalExpense;

  /// Total pengeluaran per kategori, urut dari yang terbesar.
  final Map<TransactionCategory, double> expenseByCategory;

  /// Sisa saldo bulan sebelumnya. Hanya ditampilkan sebagai informasi,
  /// **tidak** dijumlahkan ke [balance].
  final double previousMonthBalance;

  /// Sisa saldo = pemasukan − pengeluaran periode ini (bisa negatif).
  double get balance => totalIncome - totalExpense;

  /// Porsi kategori terhadap total pengeluaran, 0..1.
  double shareOf(TransactionCategory category) =>
      totalExpense == 0 ? 0 : (expenseByCategory[category] ?? 0) / totalExpense;
}
