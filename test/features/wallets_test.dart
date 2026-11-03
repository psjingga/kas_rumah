import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:keuangan_rumah_tangga/app/app.dart';
import 'package:keuangan_rumah_tangga/features/backup/data/backup_service.dart';
import 'package:keuangan_rumah_tangga/features/transactions/data/adapters/recurring_adapter.dart';
import 'package:keuangan_rumah_tangga/features/transactions/data/adapters/transaction_adapter.dart';
import 'package:keuangan_rumah_tangga/features/transactions/domain/entities/recurring_transaction.dart';
import 'package:keuangan_rumah_tangga/features/transactions/domain/entities/transaction.dart';
import 'package:keuangan_rumah_tangga/features/transactions/domain/entities/transaction_filter.dart';
import 'package:keuangan_rumah_tangga/features/transactions/presentation/providers/transaction_providers.dart';
import 'package:keuangan_rumah_tangga/features/wallets/domain/wallet.dart';
import 'package:keuangan_rumah_tangga/features/wallets/presentation/providers/wallet_providers.dart';

import 'transactions/fakes.dart';

const _bca = Wallet(
  id: 'bca',
  name: 'BCA',
  type: WalletType.bank,
  colorValue: 0xFF1E88E5,
  initialBalance: 5000000,
);

Transaction _t(
  String id,
  double amount,
  TransactionCategory c, {
  String? wallet,
  DateTime? date,
}) => Transaction(
  id: id,
  title: 'T $id',
  amount: amount,
  type: c.type,
  category: c,
  date: date ?? DateTime(2026, 11, 2),
  walletId: wallet,
);

({ProviderContainer c, TestStores s, InMemoryTransactionRepository tx}) _env({
  List<Transaction> transactions = const [],
  List<Wallet> wallets = const [],
}) {
  final s = TestStores();
  s.wallets.wallets = wallets;
  final tx = InMemoryTransactionRepository(transactions);
  final c = ProviderContainer(
    overrides: testOverrides(tx, null, null, null, null, s),
  );
  addTearDown(c.dispose);
  return (c: c, s: s, tx: tx);
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('saldo dompet', () {
    test('tanpa dompet tersimpan → Dompet Utama; data lama masuk ke sana', () {
      final e = _env(transactions: [tx('a', 50000, TransactionCategory.food)]);
      expect(e.c.read(walletsProvider), [Wallet.main]);
      expect(e.c.read(walletBalancesProvider), {Wallet.mainId: -50000});
      expect(e.c.read(totalMoneyProvider), -50000);
    });

    test(
      'saldo awal + transaksi ± transfer; transfer bukan pengeluaran',
      () async {
        final e = _env(
          wallets: [Wallet.main.copyWith(initialBalance: 200000), _bca],
          transactions: [
            _t('gaji', 9000000, TransactionCategory.salary, wallet: 'bca'),
            _t('makan', 50000, TransactionCategory.food),
          ],
        );
        await e.c
            .read(transfersProvider.notifier)
            .transfer(
              fromWalletId: 'bca',
              toWalletId: Wallet.mainId,
              amount: 1000000,
              date: DateTime(2026, 11, 3),
              note: ' Tarik tunai ',
            );

        expect(e.c.read(walletBalancesProvider), {
          Wallet.mainId: 200000 - 50000 + 1000000,
          'bca': 5000000 + 9000000 - 1000000,
        });
        expect(e.c.read(totalMoneyProvider), 14150000);
        // Ringkasan bulanan tidak berubah oleh transfer.
        expect(e.c.read(totalExpenseProvider), 50000);
        expect(e.c.read(monthTransfersProvider).single.note, 'Tarik tunai');

        expect(
          () => e.c
              .read(transfersProvider.notifier)
              .transfer(
                fromWalletId: 'bca',
                toWalletId: 'bca',
                amount: 1,
                date: today,
              ),
          throwsArgumentError,
        );
      },
    );

    test('transaksi bertanggal setelah hari ini belum dihitung', () {
      final e = _env(
        transactions: [
          _t(
            'lalu',
            1000000,
            TransactionCategory.salary,
            date: DateTime(2026, 10, 25),
          ),
          _t(
            'hari-ini',
            50000,
            TransactionCategory.food,
            date: DateTime(2026, 11, 3, 20),
          ),
          _t(
            'besok',
            450000,
            TransactionCategory.bills,
            date: DateTime(2026, 11, 4),
          ),
          _t(
            'des',
            9000000,
            TransactionCategory.salary,
            date: DateTime(2026, 12, 25),
          ),
        ],
      );
      expect(e.c.read(walletBalancesProvider)[Wallet.mainId], 950000);
      expect(e.c.read(upcomingTransactionCountProvider), 2);
    });

    test('perkiraan akhir bulan: uang saat ini + yang terjadwal', () {
      // Sama seperti data pengguna: hari ini 3 Nov.
      final e = _env(
        transactions: [
          _t(
            'gaji-abba',
            9000000,
            TransactionCategory.salary,
            date: DateTime(2026, 11, 1),
          ),
          _t(
            'gaji-umma',
            9000000,
            TransactionCategory.salary,
            date: DateTime(2026, 11, 1),
          ),
          _t(
            'shopee',
            3000000,
            TransactionCategory.bills,
            date: DateTime(2026, 11, 3),
          ),
          _t(
            'rumah',
            5000000,
            TransactionCategory.bills,
            date: DateTime(2026, 11, 5),
          ),
          _t(
            'motor',
            2265000,
            TransactionCategory.bills,
            date: DateTime(2026, 11, 8),
          ),
          _t(
            'des',
            9000000,
            TransactionCategory.salary,
            date: DateTime(2026, 12, 1),
          ),
        ],
      );
      expect(e.c.read(balanceProvider), 7735000); // Sisa Saldo November
      final f = e.c.read(monthEndForecastProvider);
      expect(f.now, 15000000);
      expect((f.incoming, f.outgoing), (0.0, 7265000.0));
      expect(f.forecast, 7735000);
      expect(e.c.read(upcomingThisMonthProvider).map((t) => t.id), [
        'rumah',
        'motor',
      ]);
    });

    test('sesuaikan saldo mencatat selisih sebagai penyesuaian', () async {
      final e = _env(wallets: [_bca]);
      final notifier = e.c.read(transfersProvider.notifier);
      final up = await notifier.adjust(
        'bca',
        actualBalance: 5250000,
        date: today,
      );
      expect(
        (up!.toWalletId, up.amount, up.isAdjustment),
        ('bca', 250000, true),
      );
      final down = await notifier.adjust(
        'bca',
        actualBalance: 5000000,
        date: today,
      );
      expect((down!.fromWalletId, down.amount), ('bca', 250000));
      expect(
        await notifier.adjust('bca', actualBalance: 5000000, date: today),
        isNull,
      );
      expect(e.c.read(walletBalancesProvider)['bca'], 5000000);
      expect(e.c.read(totalExpenseProvider), 0);
    });

    test(
      'hapus hanya bila belum dipakai; arsip tidak dihitung di total',
      () async {
        final e = _env(
          wallets: [Wallet.main, _bca],
          transactions: [_t('x', 100, TransactionCategory.food, wallet: 'bca')],
        );
        final wallets = e.c.read(walletsProvider.notifier);
        expect(() => wallets.remove('bca'), throwsStateError);

        final gopay = await wallets.add(
          name: ' GoPay ',
          type: WalletType.ewallet,
          colorValue: 0xFF00897B,
        );
        expect(gopay.name, 'GoPay');
        await wallets.remove(gopay.id);
        expect(e.c.read(walletsProvider).map((w) => w.id), [
          Wallet.mainId,
          'bca',
        ]);

        await wallets.edit(_bca.copyWith(archived: true));
        expect(e.c.read(activeWalletsProvider).map((w) => w.id), [
          Wallet.mainId,
        ]);
        expect(e.c.read(totalMoneyProvider), 0);

        await wallets.makeDefault('bca');
        expect(e.c.read(walletsProvider).first.id, 'bca');
      },
    );

    test('transaksi rutin dicatat ke dompetnya; filter per dompet', () async {
      final e = _env(wallets: [Wallet.main, _bca]);
      final r = RecurringTransaction(
        id: 'r',
        title: 'Internet',
        amount: 350000,
        type: TransactionType.expense,
        category: TransactionCategory.bills,
        dayOfMonth: 10,
        startMonth: DateTime(2026, 11),
        walletId: 'bca',
      );
      final t = await e.c
          .read(transactionsProvider.notifier)
          .recordRecurring(r, DateTime(2026, 11));
      expect(t.walletId, 'bca');

      final list = [t, _t('cash', 1, TransactionCategory.food)];
      expect(
        const TransactionFilter(walletId: 'bca').apply(list).single.id,
        t.id,
      );
      expect(
        const TransactionFilter(walletId: Wallet.mainId).apply(list).single.id,
        'cash',
      );
    });
  });

  test(
    'Hive: data lama tanpa walletId tetap terbaca, data baru menyimpannya',
    () async {
      final dir = await Directory.systemTemp.createTemp('hive_wallet');
      addTearDown(() => dir.delete(recursive: true));
      Hive
        ..init(dir.path)
        ..registerAdapter(TransactionAdapter(), override: true)
        ..registerAdapter(RecurringAdapter(), override: true);
      final box = await Hive.openBox<Transaction>('tx');
      final withWallet = _t('w', 10, TransactionCategory.food, wallet: 'bca');
      final noWallet = tx('n', 20, TransactionCategory.food, recurringId: 'r');
      await box.putAll({'w': withWallet, 'n': noWallet});
      await box.close();
      final reopened = await Hive.openBox<Transaction>('tx');
      expect(reopened.get('w'), withWallet);
      expect(reopened.get('n')!.walletId, isNull);
      expect(reopened.get('n')!.recurringId, 'r');

      final rbox = await Hive.openBox<RecurringTransaction>('rec');
      final r = listrik().copyWith(walletId: 'bca');
      await rbox.put('x', r);
      await rbox.close();
      expect((await Hive.openBox<RecurringTransaction>('rec')).get('x'), r);
      await Hive.close();
    },
  );

  test(
    'backup menyertakan dompet & transfer; v1 tetap bisa dipulihkan',
    () async {
      final s = TestStores();
      s.wallets.wallets = [Wallet.main, _bca];
      s.wallets.transfers = [
        Transfer(
          id: 'tr',
          fromWalletId: 'bca',
          toWalletId: Wallet.mainId,
          amount: 100000,
          date: DateTime(2026, 11, 3),
        ),
      ];
      final txRepo = InMemoryTransactionRepository([
        _t('a', 5000, TransactionCategory.food, wallet: 'bca'),
      ]);
      BackupService service(TestStores st, InMemoryTransactionRepository t) =>
          BackupService(
            transactions: t,
            recurring: InMemoryRecurringRepository(),
            categories: st.categories,
            budgets: st.budgets,
            goals: st.goals,
            reminderSettings: st.reminderSettings,
            wallets: st.wallets,
            debts: st.debts,
          );
      final json = service(s, txRepo).exportJson(today);
      expect(jsonDecode(json)['version'], BackupService.formatVersion);

      final fresh = TestStores();
      final freshTx = InMemoryTransactionRepository();
      final summary = await service(fresh, freshTx).restore(json);
      expect((summary.wallets, summary.transfers), (2, 1));
      expect(fresh.wallets.getWallets().last, _bca);
      expect(fresh.wallets.getTransfers().single.amount, 100000);
      expect(freshTx.getAll().single.walletId, 'bca');

      // Backup versi 1 (tanpa dompet) → dompet dikosongkan (Dompet Utama).
      final v1 = jsonEncode({
        'app': 'keuangan_rumah_tangga',
        'version': 1,
        'transactions': [
          {
            'id': 'old',
            'title': 'Lama',
            'amount': 1000,
            'type': 'expense',
            'category': 'food',
            'date': DateTime(2026, 1, 1).millisecondsSinceEpoch,
          },
        ],
      });
      await service(fresh, freshTx).restore(v1);
      expect(fresh.wallets.getWallets(), isEmpty);
      expect(freshTx.getAll().single.walletId, isNull);
    },
  );

  group('UI dompet', () {
    Future<(InMemoryTransactionRepository, TestStores)> pump(
      WidgetTester tester, {
      List<Wallet> wallets = const [],
      List<Transaction> initial = const [],
    }) async {
      tester.view
        ..physicalSize = const Size(1080, 7000)
        ..devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      final s = TestStores();
      s.wallets.wallets = wallets;
      final repo = InMemoryTransactionRepository(initial);
      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(repo, null, null, null, null, s),
          child: const KeuanganApp(),
        ),
      );
      await tester.pumpAndSettle();
      return (repo, s);
    }

    testWidgets('tambah dompet dari Lainnya → Dompet', (tester) async {
      final (_, s) = await pump(tester);
      expect(find.text('Uang saat ini'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Lainnya'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dompet'));
      await tester.pumpAndSettle();
      expect(find.text('Dompet Utama'), findsOneWidget);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nama dompet'),
        'BCA',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Saldo awal'),
        '5000000',
      );
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(s.wallets.wallets.map((w) => w.name), ['Dompet Utama', 'BCA']);
      expect(find.text('Rp 5.000.000'), findsWidgets);
    });

    testWidgets('transfer muncul di riwayat & saldo berpindah', (tester) async {
      final (_, s) = await pump(tester, wallets: [Wallet.main, _bca]);
      // Ringkasan: chip per dompet.
      expect(find.text('BCA Rp 5.000.000'), findsOneWidget);

      await tester.tap(find.text('Uang saat ini'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Transfer antar-dompet'));
      await tester.pumpAndSettle();
      // Dari: Dompet Utama → ganti ke BCA.
      await tester.tap(find.text('Dompet Utama').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('BCA').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nominal'),
        '1000000',
      );
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      final t = s.wallets.transfers.single;
      expect(
        (t.fromWalletId, t.toWalletId, t.amount),
        ('bca', Wallet.mainId, 1000000.0),
      );
      expect(find.text('Rp 4.000.000'), findsOneWidget); // BCA
      expect(find.text('Rp 1.000.000'), findsOneWidget); // Dompet Utama

      Navigator.of(tester.element(find.text('Rp 4.000.000'))).pop();
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Riwayat'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('BCA → Dompet Utama'), findsOneWidget);
    });

    testWidgets('form transaksi: pilih dompet & tampil di riwayat', (
      tester,
    ) async {
      final (repo, _) = await pump(tester, wallets: [Wallet.main, _bca]);
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Judul / Deskripsi'),
        'Listrik',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nominal'),
        '450000',
      );
      await tester.tap(find.text('Dompet Utama'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BCA').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(repo.getAll().single.walletId, 'bca');
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Riwayat'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Makanan · BCA'), findsOneWidget);
    });
  });
}
