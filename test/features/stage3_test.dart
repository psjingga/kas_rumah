import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:keuangan_rumah_tangga/app/app.dart';
import 'package:keuangan_rumah_tangga/features/backup/data/backup_service.dart';
import 'package:keuangan_rumah_tangga/features/debts/domain/debt.dart';
import 'package:keuangan_rumah_tangga/features/debts/presentation/providers/debt_providers.dart';
import 'package:keuangan_rumah_tangga/features/reminders/domain/entities/reminder_settings.dart';
import 'package:keuangan_rumah_tangga/features/reminders/domain/services/reminder_planner.dart';
import 'package:keuangan_rumah_tangga/features/transactions/data/adapters/recurring_adapter.dart';
import 'package:keuangan_rumah_tangga/features/transactions/data/adapters/transaction_adapter.dart';
import 'package:keuangan_rumah_tangga/features/transactions/data/receipt_store.dart';
import 'package:keuangan_rumah_tangga/features/transactions/domain/entities/recurring_transaction.dart';
import 'package:keuangan_rumah_tangga/features/transactions/domain/entities/transaction.dart';
import 'package:keuangan_rumah_tangga/features/transactions/domain/entities/transaction_filter.dart';
import 'package:keuangan_rumah_tangga/features/transactions/presentation/providers/recurring_providers.dart';
import 'package:keuangan_rumah_tangga/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:keuangan_rumah_tangga/features/wallets/domain/wallet.dart';
import 'package:keuangan_rumah_tangga/features/wallets/presentation/providers/wallet_providers.dart';

import 'transactions/fakes.dart';

/// Uang jajan Rp 50.000 tiap Senin, mulai November 2026.
RecurringTransaction _jajan({int? total}) => RecurringTransaction(
  id: 'jajan',
  title: 'Uang jajan',
  amount: 50000,
  type: TransactionType.expense,
  category: TransactionCategory.otherExpense,
  dayOfMonth: 1,
  startMonth: DateTime(2026, 11),
  frequency: RecurrenceFrequency.weekly,
  weekday: DateTime.monday,
  totalOccurrences: total,
);

({ProviderContainer c, TestStores s, InMemoryTransactionRepository tx}) _env({
  List<RecurringTransaction> recurring = const [],
  List<Transaction> transactions = const [],
}) {
  final s = TestStores();
  final tx = InMemoryTransactionRepository(transactions);
  final c = ProviderContainer(
    overrides: testOverrides(
      tx,
      InMemoryRecurringRepository(recurring),
      null,
      null,
      null,
      s,
    ),
  );
  addTearDown(c.dispose);
  return (c: c, s: s, tx: tx);
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('frekuensi & cicilan', () {
    test('mingguan: semua Senin di bulan itu', () {
      final r = _jajan();
      expect(r.scheduleLabel, 'Tiap Senin');
      expect(r.occurrencesIn(DateTime(2026, 11)).map((o) => o.date.day), [
        2,
        9,
        16,
        23,
        30,
      ]);
      expect(r.occurrencesIn(DateTime(2026, 12)).first.number, 6);
      expect(r.occurrencesIn(DateTime(2026, 10)), isEmpty);
      expect(r.monthlyEquivalent, closeTo(216666.67, .01));
    });

    test('tahunan: hanya di bulannya', () {
      final pajak = listrik().copyWith(
        frequency: RecurrenceFrequency.yearly,
        monthOfYear: 3,
        dayOfMonth: 15,
      );
      expect(pajak.scheduleLabel, 'Tiap 15 Mar');
      expect(pajak.occurrencesIn(DateTime(2026, 11)), isEmpty);
      final o = pajak.occurrencesIn(DateTime(2027, 3)).single;
      expect((o.date, o.number), (DateTime(2027, 3, 15), 1));
      expect(pajak.occurrencesIn(DateTime(2028, 3)).single.number, 2);
    });

    test('cicilan 3x berhenti sendiri', () {
      final motor = listrik().copyWith(totalOccurrences: () => 3);
      expect(motor.lastOccurrence, DateTime(2027, 1, 5));
      expect(motor.occurrencesIn(DateTime(2027, 1)).single.number, 3);
      expect(motor.occurrencesIn(DateTime(2027, 2)), isEmpty);
      final weekly = _jajan(total: 2);
      expect(weekly.occurrencesIn(DateTime(2026, 11)).map((o) => o.number), [
        1,
        2,
      ]);
      expect(weekly.lastOccurrence, DateTime(2026, 11, 9));
    });

    test(
      'pending mingguan per Senin; dicatat lebih awal tetap terhitung',
      () async {
        final e = _env(recurring: [_jajan()]);
        expect(e.c.read(pendingRecurringProvider), hasLength(5));
        // Dicatat hari Minggu 8 Nov → masuk minggu Senin 2 Nov.
        await e.c
            .read(transactionsProvider.notifier)
            .recordRecurring(
              _jajan(),
              DateTime(2026, 11),
              date: DateTime(2026, 11, 8),
            );
        expect(e.c.read(pendingRecurringProvider).map((o) => o.date.day), [
          9,
          16,
          23,
          30,
        ]);
        await e.c
            .read(transactionsProvider.notifier)
            .recordAllRecurring(e.c.read(pendingRecurringProvider));
        expect(e.c.read(pendingRecurringProvider), isEmpty);
        expect(e.c.read(totalExpenseProvider), 250000);
      },
    );

    test('pengingat untuk setiap jatuh tempo mingguan', () {
      final plan = planReminders(
        recurring: [_jajan()],
        transactions: const [],
        settings: const ReminderSettings(daysBefore: 0),
        now: today,
        monthsAhead: 1,
      );
      expect(plan.map((p) => p.dueDate.day), [9, 16, 23, 30]);
    });
  });

  test('Hive: frekuensi, cicilan, catatan & foto tersimpan', () async {
    final dir = await Directory.systemTemp.createTemp('hive_stage3');
    addTearDown(() => dir.delete(recursive: true));
    Hive
      ..init(dir.path)
      ..registerAdapter(TransactionAdapter(), override: true)
      ..registerAdapter(RecurringAdapter(), override: true);
    final rbox = await Hive.openBox<RecurringTransaction>('r');
    final r = _jajan(total: 12).copyWith(walletId: 'bca');
    await rbox.put('x', r);
    await rbox.close();
    expect((await Hive.openBox<RecurringTransaction>('r')).get('x'), r);

    final tbox = await Hive.openBox<Transaction>('t');
    final t = tx(
      'a',
      1,
      TransactionCategory.food,
    ).copyWith(note: 'Beli di pasar', photoPath: () => '/foto/struk.jpg');
    await tbox.put('a', t);
    await tbox.close();
    expect((await Hive.openBox<Transaction>('t')).get('a'), t);
    await Hive.close();
  });

  test('catatan ikut dicari', () {
    final t = tx('a', 1, TransactionCategory.food).copyWith(note: 'Arisan RT');
    expect(const TransactionFilter(query: 'arisan').apply([t]), [t]);
  });

  test('foto struk disalin & yang yatim dibersihkan', () async {
    final tmp = await Directory.systemTemp.createTemp('receipts');
    addTearDown(() => tmp.delete(recursive: true));
    final src = File('${tmp.path}/kamera.jpg')..writeAsStringSync('img');
    final store = ReceiptStore(Directory('${tmp.path}/receipts'));
    final a = await store.save(src.path);
    final b = await store.save(src.path);
    expect(File(a).existsSync(), isTrue);
    expect(a, endsWith('.jpg'));
    expect(await store.cleanupOrphans({a}), 1);
    expect(File(b).existsSync(), isFalse);
  });

  group('utang & piutang', () {
    test('pinjam ke dompet, bayar sebagian lalu lunas', () async {
      final e = _env();
      final debts = e.c.read(debtsProvider.notifier);
      final d = await debts.add(
        person: ' Bu RT ',
        direction: DebtDirection.iOwe,
        amount: 500000,
        date: DateTime(2026, 11, 1),
        dueDate: DateTime(2026, 11, 2),
        walletId: Wallet.mainId,
      );
      expect(d.person, 'Bu RT');
      // Pinjaman menambah saldo dompet, bukan pemasukan.
      expect(e.c.read(walletBalancesProvider)[Wallet.mainId], 500000);
      expect(e.c.read(totalIncomeProvider), 0);
      expect(e.c.read(debtTotalsProvider), (iOwe: 500000.0, theyOwe: 0.0));
      expect(e.c.read(debtsProvider).single.isOverdue(today), isTrue);

      await debts.pay(
        d.id,
        amount: 200000,
        date: today,
        walletId: Wallet.mainId,
      );
      expect(e.c.read(walletBalancesProvider)[Wallet.mainId], 300000);
      expect(e.c.read(debtsProvider).single.remaining, 300000);
      expect(
        () => debts.pay(d.id, amount: 400000, date: today),
        throwsArgumentError,
      );

      await debts.pay(d.id, amount: 300000, date: today);
      final settled = e.c.read(debtsProvider).single;
      expect(settled.isSettled, isTrue);
      expect(settled.isOverdue(today), isFalse);
      expect(e.c.read(debtTotalsProvider).iOwe, 0);

      // Batalkan pembayaran yang lewat dompet → perpindahan uangnya hilang.
      final viaWallet = settled.payments.firstWhere(
        (p) => p.transferId != null,
      );
      await debts.removePayment(d.id, viaWallet.id);
      expect(e.c.read(walletBalancesProvider)[Wallet.mainId], 500000);

      await debts.remove(d.id);
      expect(e.c.read(debtsProvider), isEmpty);
      expect(e.s.wallets.transfers, isEmpty);
    });

    test('piutang mengurangi dompet; pengingat jatuh tempo', () async {
      final e = _env();
      await e.c
          .read(debtsProvider.notifier)
          .add(
            person: 'Pak Budi',
            direction: DebtDirection.theyOwe,
            amount: 1000000,
            date: DateTime(2026, 11, 1),
            dueDate: DateTime(2026, 11, 20),
            walletId: Wallet.mainId,
          );
      expect(e.c.read(walletBalancesProvider)[Wallet.mainId], -1000000);
      expect(e.c.read(totalExpenseProvider), 0);

      final plan = planReminders(
        recurring: const [],
        transactions: const [],
        settings: const ReminderSettings(),
        now: today,
        debts: e.c.read(debtsProvider),
      );
      final r = plan.single;
      expect(r.title, 'Piutang: Pak Budi');
      expect(r.fireAt, DateTime(2026, 11, 19, 8));
      expect(r.recurringId, startsWith(debtReminderPrefix));
      expect(r.body, contains('sisa Rp 1.000.000'));
    });

    test('backup menyertakan utang-piutang', () async {
      final s = TestStores();
      s.debts.debts = [
        Debt(
          id: 'd',
          person: 'Bu RT',
          direction: DebtDirection.iOwe,
          amount: 500000,
          date: DateTime(2026, 11, 1),
          dueDate: DateTime(2026, 12, 1),
          payments: [
            DebtPayment(id: 'p', amount: 100000, date: DateTime(2026, 11, 2)),
          ],
        ),
      ];
      BackupService service(TestStores st) => BackupService(
        transactions: InMemoryTransactionRepository(),
        recurring: InMemoryRecurringRepository([_jajan(total: 4)]),
        categories: st.categories,
        budgets: st.budgets,
        goals: st.goals,
        reminderSettings: st.reminderSettings,
        wallets: st.wallets,
        debts: st.debts,
      );
      final json = service(s).exportJson(today);
      final fresh = TestStores();
      final rec = InMemoryRecurringRepository();
      final restored = BackupService(
        transactions: InMemoryTransactionRepository(),
        recurring: rec,
        categories: fresh.categories,
        budgets: fresh.budgets,
        goals: fresh.goals,
        reminderSettings: fresh.reminderSettings,
        wallets: fresh.wallets,
        debts: fresh.debts,
      );
      expect((await restored.restore(json)).debts, 1);
      expect(fresh.debts.getAll().single, s.debts.debts.single);
      expect(rec.getAll().single, _jajan(total: 4));
    });
  });

  group('UI tahap 3', () {
    Future<
      (InMemoryTransactionRepository, InMemoryRecurringRepository, TestStores)
    >
    pump(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(1080, 7000)
        ..devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      final s = TestStores();
      final repo = InMemoryTransactionRepository();
      final rec = InMemoryRecurringRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(repo, rec, null, null, null, s),
          child: const KeuanganApp(),
        ),
      );
      await tester.pumpAndSettle();
      return (repo, rec, s);
    }

    Future<void> openMore(WidgetTester tester, String item) async {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Lainnya'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(item));
      await tester.pumpAndSettle();
    }

    testWidgets('catatan tersimpan di transaksi', (tester) async {
      final (repo, _, _) = await pump(tester);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Judul / Deskripsi'),
        'Sayur',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nominal'),
        '25000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Catatan (opsional)'),
        'Pasar Kranji',
      );
      expect(find.text('Foto struk'), findsOneWidget);
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(repo.getAll().single.note, 'Pasar Kranji');
    });

    testWidgets('rutin mingguan dengan cicilan', (tester) async {
      final (_, rec, _) = await pump(tester);
      await openMore(tester, 'Transaksi Rutin');
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Judul / Deskripsi'),
        'Kredit HP',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nominal default'),
        '300000',
      );
      await tester.tap(find.text('Mingguan'));
      await tester.pumpAndSettle();
      expect(find.text('Setiap hari'), findsOneWidget);
      await tester.tap(find.text('Cicilan / ada batas waktu'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Jumlah kali bayar'),
        '4',
      );
      await tester.pump();
      expect(find.text('Lunas setelah 23 Nov 2026'), findsOneWidget);
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      final r = rec.getAll().single;
      expect(
        (r.frequency, r.weekday, r.totalOccurrences),
        (RecurrenceFrequency.weekly, DateTime.monday, 4),
      );
      expect(find.text('Tiap Senin · Makanan · Cicilan 0/4'), findsOneWidget);
    });

    testWidgets('utang: catat lalu lunasi', (tester) async {
      final (_, _, s) = await pump(tester);
      await openMore(tester, 'Utang & Piutang');
      expect(find.text('Tidak ada utang/piutang aktif'), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Pinjam dari siapa'),
        'Bu RT',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nominal'),
        '500000',
      );
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(s.debts.debts.single.walletId, Wallet.mainId);
      expect(find.text('Bu RT'), findsOneWidget);

      await tester.tap(find.text('Bu RT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Catat pembayaran'));
      await tester.pumpAndSettle();
      // Nominal otomatis = sisa.
      expect(find.text('500.000'), findsOneWidget);
      await tester.tap(find.text('Simpan').last);
      await tester.pumpAndSettle();
      expect(find.text('Lunas! 🎉'), findsOneWidget);
      expect(s.debts.debts.single.remaining, 0);
    });
  });
}
