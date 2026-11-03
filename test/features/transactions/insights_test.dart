import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keuangan_rumah_tangga/features/transactions/domain/entities/transaction.dart';
import 'package:keuangan_rumah_tangga/features/transactions/domain/entities/transaction_filter.dart';
import 'package:keuangan_rumah_tangga/features/transactions/presentation/providers/transaction_providers.dart';

import 'fakes.dart';

final _data = [
  tx(
    'gaji-okt',
    5000000,
    TransactionCategory.salary,
    date: DateTime(2026, 10, 25),
  ),
  tx(
    'makan-okt',
    1500000,
    TransactionCategory.food,
    date: DateTime(2026, 10, 10),
  ),
  tx(
    'gaji-nov',
    5000000,
    TransactionCategory.salary,
    date: DateTime(2026, 11, 1),
  ),
  tx(
    'listrik-nov',
    450000,
    TransactionCategory.bills,
    date: DateTime(2026, 11, 5),
  ),
  tx('mei', 100000, TransactionCategory.food, date: DateTime(2026, 5, 2)),
];

ProviderContainer _container() {
  final c = ProviderContainer(
    overrides: testOverrides(InMemoryTransactionRepository(_data)),
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('sisa bulan lalu', () {
    test('hanya informasi, tidak dijumlahkan ke saldo bulan ini', () {
      final s = _container().read(financeSummaryProvider);
      // Oktober: +5jt −1,5jt = 3,5jt (Mei tidak ikut dihitung).
      expect(s.previousMonthBalance, 3500000);
      expect(s.balance, 4550000);
    });

    test('bulan lalu tanpa transaksi → 0', () {
      final c = _container();
      c.read(selectedMonthProvider.notifier).select(DateTime(2026, 5, 20));
      expect(c.read(financeSummaryProvider).previousMonthBalance, 0);
      expect(c.read(financeSummaryProvider).balance, -100000);
    });
  });

  test('tren 6 bulan diakhiri bulan terpilih', () {
    final trend = _container().read(monthlyTrendProvider);
    expect(trend.map((t) => t.month.month), [6, 7, 8, 9, 10, 11]);
    expect(trend[4], (
      month: DateTime(2026, 10),
      income: 5000000.0,
      expense: 1500000.0,
    ));
    expect(trend.last.expense, 450000);
    // Mei di luar jendela 6 bulan.
    expect(trend.every((t) => t.month.month != 5), isTrue);
  });

  group('TransactionFilter', () {
    List<String> ids(TransactionFilter f) =>
        f.apply(_data).map((t) => t.id).toList();

    test('kata kunci mencocokkan judul, kategori, dan nominal', () {
      expect(ids(const TransactionFilter(query: 'LISTRIK')), ['listrik-nov']);
      expect(ids(const TransactionFilter(query: 'makanan')), [
        'makan-okt',
        'mei',
      ]);
      expect(ids(const TransactionFilter(query: '450')), ['listrik-nov']);
      expect(ids(const TransactionFilter(query: '1.500.000')), ['makan-okt']);
    });

    test('jenis & kategori; ganti jenis melepas kategori yang tak cocok', () {
      const f = TransactionFilter(category: TransactionCategory.food);
      expect(ids(f), ['makan-okt', 'mei']);
      expect(ids(f.withQuery('okt')), ['makan-okt']); // judul cocok
      expect(f.withType(TransactionType.income).category, isNull);
      expect(
        f.withType(TransactionType.expense).category,
        TransactionCategory.food,
      );
      expect(ids(const TransactionFilter(type: TransactionType.income)), [
        'gaji-okt',
        'gaji-nov',
      ]);
      expect(const TransactionFilter().isEmpty, isTrue);
    });
  });
}
