import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:keuangan_rumah_tangga/features/transactions/data/adapters/recurring_adapter.dart';
import 'package:keuangan_rumah_tangga/features/transactions/data/adapters/transaction_adapter.dart';
import 'package:keuangan_rumah_tangga/features/transactions/data/repositories/hive_recurring_repository.dart';
import 'package:keuangan_rumah_tangga/features/transactions/domain/entities/recurring_transaction.dart';
import 'package:keuangan_rumah_tangga/features/transactions/domain/entities/transaction.dart';
import 'package:keuangan_rumah_tangga/features/transactions/presentation/providers/recurring_providers.dart';
import 'package:keuangan_rumah_tangga/features/transactions/presentation/providers/transaction_providers.dart';

import 'fakes.dart';

ProviderContainer _container({
  List<Transaction> transactions = const [],
  List<RecurringTransaction> recurring = const [],
}) {
  final c = ProviderContainer(
    overrides: testOverrides(
      InMemoryTransactionRepository(transactions),
      InMemoryRecurringRepository(recurring),
    ),
  );
  addTearDown(c.dispose);
  return c;
}

/// Adapter format lama (sebelum ada `recurringId`), untuk uji kompatibilitas.
class _LegacyTransactionAdapter extends TypeAdapter<Transaction> {
  @override
  final int typeId = TransactionAdapter.id;

  @override
  Transaction read(BinaryReader reader) => throw UnimplementedError();

  @override
  void write(BinaryWriter writer, Transaction obj) => writer
    ..writeString(obj.id)
    ..writeString(obj.title)
    ..writeDouble(obj.amount)
    ..writeString(obj.type.name)
    ..writeString(obj.category.id)
    ..writeInt(obj.date.millisecondsSinceEpoch);
}

void main() {
  group('RecurringTransaction', () {
    test('tanggal jatuh tempo dipotong ke akhir bulan', () {
      final r = listrik(day: 31);
      expect(r.dueDate(DateTime(2026, 11)), DateTime(2026, 11, 30));
      expect(r.dueDate(DateTime(2027, 2)), DateTime(2027, 2, 28));
      expect(r.dueDate(DateTime(2026, 12)), DateTime(2026, 12, 31));
    });

    test('berlaku mulai startMonth dan hanya bila aktif', () {
      final r = listrik();
      expect(r.appliesTo(DateTime(2026, 10)), isFalse);
      expect(r.appliesTo(DateTime(2026, 11)), isTrue);
      expect(r.appliesTo(DateTime(2027, 3)), isTrue);
      expect(r.copyWith(active: false).appliesTo(DateTime(2026, 11)), isFalse);
    });
  });

  group('per bulan', () {
    test('ringkasan hanya menghitung transaksi bulan terpilih', () {
      final c = _container(
        transactions: [
          tx(
            'okt',
            1000000,
            TransactionCategory.salary,
            date: DateTime(2026, 10, 25),
          ),
          tx(
            'nov',
            200000,
            TransactionCategory.food,
            date: DateTime(2026, 11, 2),
          ),
        ],
      );
      expect(c.read(selectedMonthProvider), DateTime(2026, 11));
      expect(c.read(balanceProvider), -200000);

      c.read(selectedMonthProvider.notifier).previous();
      expect(c.read(monthTransactionsProvider).single.id, 'okt');
      expect(c.read(balanceProvider), 1000000);
      expect(c.read(selectedMonthProvider.notifier).isThisMonth, isFalse);

      c.read(selectedMonthProvider.notifier).goToThisMonth();
      expect(c.read(selectedMonthProvider), DateTime(2026, 11));
    });

    test('Desember → Januari pindah tahun', () {
      final c = _container();
      final month = c.read(selectedMonthProvider.notifier)
        ..next()
        ..next();
      expect(c.read(selectedMonthProvider), DateTime(2027));
      month.previous();
      expect(c.read(selectedMonthProvider), DateTime(2026, 12));
    });
  });

  group('transaksi rutin', () {
    test('muncul sebagai belum dicatat, hilang setelah dicatat', () async {
      final c = _container(recurring: [listrik()]);
      final notifier = c.read(transactionsProvider.notifier);
      expect(c.read(pendingRecurringProvider).single.id, 'listrik');

      // Nominal khusus bulan ini berbeda dari default.
      final t = await notifier.recordRecurring(
        listrik(),
        DateTime(2026, 11),
        amount: 520000,
      );
      expect(t.amount, 520000);
      expect(t.date, DateTime(2026, 11, 5));
      expect(t.recurringId, 'listrik');
      expect(c.read(pendingRecurringProvider), isEmpty);
      expect(c.read(totalExpenseProvider), 520000);

      // Mencatat ulang di bulan yang sama tidak membuat data dobel.
      expect(await notifier.recordRecurring(listrik(), DateTime(2026, 11)), t);
      expect(c.read(monthTransactionsProvider), hasLength(1));

      // Bulan berikutnya muncul lagi; sebelum startMonth tidak.
      c.read(selectedMonthProvider.notifier).next();
      expect(c.read(pendingRecurringProvider), hasLength(1));
      c.read(selectedMonthProvider.notifier)
        ..previous()
        ..previous();
      expect(c.read(pendingRecurringProvider), isEmpty);
    });

    test('hapus transaksi rutin yang tercatat → muncul lagi', () async {
      final c = _container(recurring: [listrik()]);
      final notifier = c.read(transactionsProvider.notifier);
      final t = await notifier.recordRecurring(listrik(), DateTime(2026, 11));
      await notifier.remove(t.id);
      expect(c.read(pendingRecurringProvider), hasLength(1));
    });

    test('catat semua memakai nominal default', () async {
      final gaji = RecurringTransaction(
        id: 'gaji',
        title: 'Gaji',
        amount: 8000000,
        type: TransactionType.income,
        category: TransactionCategory.salary,
        dayOfMonth: 25,
        startMonth: DateTime(2026, 1),
      );
      final c = _container(recurring: [listrik(), gaji]);
      await c
          .read(transactionsProvider.notifier)
          .recordAllRecurring(
            c.read(pendingRecurringProvider),
            DateTime(2026, 11),
          );
      expect(c.read(pendingRecurringProvider), isEmpty);
      expect(c.read(balanceProvider), 8000000 - 450000);
    });

    test('ubah nominal default & nonaktifkan template', () async {
      final repo = InMemoryRecurringRepository([listrik()]);
      final c = ProviderContainer(
        overrides: testOverrides(InMemoryTransactionRepository(), repo),
      );
      addTearDown(c.dispose);
      final notifier = c.read(recurringProvider.notifier);

      await notifier.save(listrik().copyWith(amount: 500000));
      expect(repo.getAll().single.amount, 500000);
      expect(c.read(pendingRecurringProvider).single.amount, 500000);

      await notifier.save(listrik().copyWith(active: false));
      expect(c.read(pendingRecurringProvider), isEmpty);

      await notifier.remove('listrik');
      expect(repo.getAll(), isEmpty);
    });
  });

  test('Hive: data lama tanpa recurringId tetap terbaca', () async {
    final dir = await Directory.systemTemp.createTemp('hive_recurring');
    addTearDown(() => dir.delete(recursive: true));
    Hive
      ..init(dir.path)
      ..registerAdapter(_LegacyTransactionAdapter(), override: true);

    final lama = tx('lama', 75000, TransactionCategory.food);
    final boxLama = await Hive.openBox<Transaction>('tx');
    await boxLama.put(lama.id, lama);
    await boxLama.close();

    Hive
      ..registerAdapter(TransactionAdapter(), override: true)
      ..registerAdapter(RecurringAdapter(), override: true);
    final box = await Hive.openBox<Transaction>('tx');
    expect(box.get('lama'), lama);

    // Format baru: recurringId ikut tersimpan.
    final baru = tx('baru', 1, TransactionCategory.bills, recurringId: 'r1');
    await box.put(baru.id, baru);
    await box.close();
    expect((await Hive.openBox<Transaction>('tx')).get('baru'), baru);

    final rBox = await Hive.openBox<RecurringTransaction>('rec');
    await HiveRecurringRepository(rBox).save(listrik(day: 31));
    await rBox.close();
    final dibuka = await Hive.openBox<RecurringTransaction>('rec');
    expect(HiveRecurringRepository(dibuka).getAll(), [listrik(day: 31)]);
    await Hive.close();
  });
}
