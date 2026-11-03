import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:keuangan_rumah_tangga/core/utils/formatters.dart';
import 'package:keuangan_rumah_tangga/features/transactions/data/adapters/transaction_adapter.dart';
import 'package:keuangan_rumah_tangga/features/transactions/data/repositories/hive_transaction_repository.dart';
import 'package:keuangan_rumah_tangga/features/transactions/domain/entities/finance_summary.dart';
import 'package:keuangan_rumah_tangga/features/transactions/domain/entities/transaction.dart';
import 'package:keuangan_rumah_tangga/features/transactions/presentation/providers/transaction_providers.dart';

import 'fakes.dart';

ProviderContainer _container(
  InMemoryTransactionRepository repo, [
  InMemoryRecurringRepository? recurring,
]) {
  final c = ProviderContainer(overrides: testOverrides(repo, recurring));
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('FinanceSummary', () {
    test('menghitung pemasukan, pengeluaran, saldo, dan per kategori', () {
      final s = FinanceSummary.from([
        tx('1', 5000000, TransactionCategory.salary),
        tx('2', 300000, TransactionCategory.food),
        tx('3', 700000, TransactionCategory.bills),
        tx('4', 200000, TransactionCategory.food),
      ]);

      expect(s.totalIncome, 5000000);
      expect(s.totalExpense, 1200000);
      expect(s.balance, 3800000);
      // Urut dari pengeluaran terbesar; pemasukan tidak ikut.
      expect(s.expenseByCategory, {
        TransactionCategory.bills: 700000,
        TransactionCategory.food: 500000,
      });
      expect(s.shareOf(TransactionCategory.food), closeTo(.4167, .0001));
    });

    test('saldo bisa negatif dan share 0 bila tanpa pengeluaran', () {
      expect(
        FinanceSummary.from([tx('1', 100, TransactionCategory.food)]).balance,
        -100,
      );
      expect(FinanceSummary.empty.shareOf(TransactionCategory.food), 0);
    });
  });

  group('TransactionsNotifier', () {
    test('memuat data awal dari repository, terbaru lebih dulu', () {
      final c = _container(
        InMemoryTransactionRepository([
          tx('lama', 1, TransactionCategory.food, date: DateTime(2026, 1, 1)),
          tx('baru', 1, TransactionCategory.food, date: DateTime(2026, 6, 1)),
        ]),
      );
      expect(c.read(transactionsProvider).map((t) => t.id), ['baru', 'lama']);
    });

    test(
      'tambah transaksi menyimpan ke repository & memperbarui total',
      () async {
        final repo = InMemoryTransactionRepository();
        final c = _container(repo);
        final notifier = c.read(transactionsProvider.notifier);

        await notifier.add(
          title: '  Gaji November ',
          amount: 6000000,
          type: TransactionType.income,
          category: TransactionCategory.salary,
          date: DateTime(2026, 11, 1),
        );
        final belanja = await notifier.add(
          title: 'Belanja bulanan',
          amount: 1500000,
          type: TransactionType.expense,
          category: TransactionCategory.groceries,
          date: DateTime(2026, 11, 2),
        );

        expect(repo.getAll(), hasLength(2));
        expect(c.read(transactionsProvider).first, belanja);
        expect(c.read(transactionsProvider).last.title, 'Gaji November');
        expect(c.read(totalIncomeProvider), 6000000);
        expect(c.read(totalExpenseProvider), 1500000);
        expect(c.read(balanceProvider), 4500000);
      },
    );

    test('menolak nominal ≤ 0 dan kategori yang tidak cocok', () {
      final notifier = _container(
        InMemoryTransactionRepository(),
      ).read(transactionsProvider.notifier);

      expect(
        () => notifier.add(
          title: 'x',
          amount: 0,
          type: TransactionType.expense,
          category: TransactionCategory.food,
          date: DateTime(2026),
        ),
        throwsArgumentError,
      );
      expect(
        () => notifier.add(
          title: 'x',
          amount: 10,
          type: TransactionType.expense,
          category: TransactionCategory.salary,
          date: DateTime(2026),
        ),
        throwsArgumentError,
      );
    });

    test('hapus lalu urungkan', () async {
      final repo = InMemoryTransactionRepository([
        tx('1', 5000, TransactionCategory.salary),
        tx('2', 2000, TransactionCategory.food),
      ]);
      final c = _container(repo);
      final notifier = c.read(transactionsProvider.notifier);

      final removed = await notifier.remove('2');
      expect(removed?.id, '2');
      expect(repo.getAll().map((t) => t.id), ['1']);
      expect(c.read(balanceProvider), 5000);

      expect(await notifier.remove('tidak-ada'), isNull);

      await notifier.restore(removed!);
      expect(repo.getAll(), hasLength(2));
      expect(c.read(balanceProvider), 3000);
    });
  });

  test('TransactionAdapter: simpan & baca ulang dari Hive', () async {
    final dir = await Directory.systemTemp.createTemp('hive_test');
    addTearDown(() => dir.delete(recursive: true));
    Hive
      ..init(dir.path)
      ..registerAdapter(TransactionAdapter());
    final box = await Hive.openBox<Transaction>('t');
    addTearDown(Hive.close);

    final asli = Transaction(
      id: 'abc',
      title: 'Listrik',
      amount: 450000.5,
      type: TransactionType.expense,
      category: TransactionCategory.bills,
      date: DateTime(2026, 11, 3, 10, 30),
    );
    await HiveTransactionRepository(box).save(asli);
    await box.close();

    final dibuka = await Hive.openBox<Transaction>('t');
    expect(HiveTransactionRepository(dibuka).getAll(), [asli]);
  });

  test('Fmt.parseAmount & ThousandsInputFormatter', () {
    expect(Fmt.parseAmount('1.500.000'), 1500000);
    expect(Fmt.parseAmount(''), isNull);
    final v = const ThousandsInputFormatter().formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '12a3456'),
    );
    expect(v.text, '123.456');
  });
}
