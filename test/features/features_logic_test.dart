import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:keuangan_rumah_tangga/features/backup/data/backup_service.dart';
import 'package:keuangan_rumah_tangga/features/budgets/domain/budget.dart';
import 'package:keuangan_rumah_tangga/features/budgets/presentation/providers/budget_alerts.dart';
import 'package:keuangan_rumah_tangga/features/budgets/presentation/providers/budget_providers.dart';
import 'package:keuangan_rumah_tangga/features/goals/presentation/providers/goal_providers.dart';
import 'package:keuangan_rumah_tangga/features/reminders/domain/entities/planned_reminder.dart';
import 'package:keuangan_rumah_tangga/features/reminders/domain/entities/reminder_settings.dart';
import 'package:keuangan_rumah_tangga/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:keuangan_rumah_tangga/features/settings/domain/security.dart';
import 'package:keuangan_rumah_tangga/features/settings/presentation/providers/settings_providers.dart';
import 'package:keuangan_rumah_tangga/features/transactions/domain/entities/transaction.dart';
import 'package:keuangan_rumah_tangga/features/transactions/presentation/providers/category_providers.dart';
import 'package:keuangan_rumah_tangga/features/transactions/presentation/providers/transaction_providers.dart';

import 'transactions/fakes.dart';

typedef _Env = ({
  ProviderContainer c,
  InMemoryTransactionRepository tx,
  InMemoryRecurringRepository rec,
  TestStores stores,
  FakeNotificationService notif,
  InMemoryNotificationLogRepository log,
});

_Env _env({
  List<Transaction> transactions = const [],
  DateTime Function()? clock,
}) {
  final tx = InMemoryTransactionRepository(transactions);
  final rec = InMemoryRecurringRepository([listrik()]);
  final stores = TestStores();
  final notif = FakeNotificationService();
  final log = InMemoryNotificationLogRepository();
  final c = ProviderContainer(
    overrides: testOverrides(tx, rec, notif, log, clock, stores),
  );
  addTearDown(c.dispose);
  return (c: c, tx: tx, rec: rec, stores: stores, notif: notif, log: log);
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  group('kategori buatan sendiri', () {
    test('transaksi lama ikut nama/warna terbaru; dihapus → penanda', () async {
      final e = _env();
      final cats = e.c.read(customCategoriesProvider.notifier);
      final arisan = await cats.add(
        label: ' Arisan ',
        type: TransactionType.expense,
        iconKey: 'family',
        color: Colors.purple,
      );
      expect(arisan.label, 'Arisan');
      expect(
        e.c.read(categoriesOfTypeProvider(TransactionType.expense)).last,
        arisan,
      );
      await e.c
          .read(transactionsProvider.notifier)
          .add(
            title: 'Arisan RT',
            amount: 100000,
            type: TransactionType.expense,
            category: arisan,
            date: DateTime(2026, 11, 2),
          );

      await cats.edit(arisan.copyWith(label: 'Arisan Keluarga'));
      expect(
        e.c.read(transactionsProvider).single.category.label,
        'Arisan Keluarga',
      );

      // Data dari penyimpanan hanya berisi ID; setelah kategori dihapus,
      // transaksi tetap ada dengan penanda "Kategori dihapus".
      await cats.remove(arisan.id);
      final t = e.c.read(transactionsProvider).single;
      expect(t.category.isMissing, isTrue);
      expect(t.category.id, arisan.id);
    });

    test('kategori bawaan tidak bisa diubah', () {
      final e = _env();
      expect(
        () => e.c
            .read(customCategoriesProvider.notifier)
            .edit(TransactionCategory.food.copyWith(label: 'x')),
        throwsArgumentError,
      );
      expect(
        TransactionCategory.byId('food', TransactionType.expense),
        TransactionCategory.food,
      );
    });
  });

  group('anggaran', () {
    test('status, tingkat, dan peringatan sekali per tingkat', () async {
      final e = _env(
        transactions: [
          tx('a', 2500000, TransactionCategory.food),
          tx('b', 600000, TransactionCategory.transport),
          tx('c', 100000, TransactionCategory.health),
        ],
      );
      final limits = e.c.read(budgetLimitsProvider.notifier);
      await limits.setLimit('food', 3000000);
      await limits.setLimit('transport', 500000);
      await limits.setLimit('health', 1000000);

      final st = e.c.read(budgetStatusProvider);
      expect(st.map((s) => (s.category.id, s.level)), [
        ('transport', BudgetLevel.over),
        ('food', BudgetLevel.warning),
        ('health', BudgetLevel.safe),
      ]);
      expect(st.first.remaining, -100000);

      Future<List<BudgetAlert>> dispatch() => dispatchBudgetAlerts(
        statuses: e.c.read(currentBudgetStatusProvider),
        month: DateTime(2026, 11),
        repository: e.stores.budgets,
        notifications: e.notif,
        inbox: e.c.read(notificationInboxProvider.notifier),
      );

      final sent = await dispatch();
      expect(sent.map((a) => a.title), [
        'Anggaran Transportasi terlampaui',
        'Anggaran Makanan hampir habis',
      ]);
      expect(sent.first.body, contains('lebih Rp 100.000'));
      expect(e.notif.shown, hasLength(2));
      expect(e.c.read(notificationInboxProvider), hasLength(2));

      // Tidak dikirim ulang.
      expect(await dispatch(), isEmpty);

      // Makanan naik ke 100% → peringatan baru "terlampaui".
      await e.c
          .read(transactionsProvider.notifier)
          .add(
            title: 'Makan',
            amount: 600000,
            type: TransactionType.expense,
            category: TransactionCategory.food,
            date: DateTime(2026, 11, 3),
          );
      expect((await dispatch()).single.title, 'Anggaran Makanan terlampaui');

      await limits.setLimit('health', null);
      expect(e.c.read(budgetLimitsProvider).containsKey('health'), isFalse);
    });
  });

  group('target tabungan', () {
    test(
      'setor & tarik mencatat transaksi; batal setor menghapusnya',
      () async {
        final e = _env();
        final goals = e.c.read(goalsProvider.notifier);
        final g = await goals.add(
          name: 'Dana darurat',
          target: 10000000,
          iconKey: 'savings',
          colorValue: 0xFF00897B,
          deadline: DateTime(2027, 10),
        );
        await goals.deposit(g.id, amount: 1000000, date: DateTime(2026, 11, 3));
        await goals.deposit(g.id, amount: -200000, date: DateTime(2026, 11, 4));
        await goals.deposit(
          g.id,
          amount: 500000,
          date: DateTime(2026, 11, 5),
          recordTransaction: false,
        );

        final saved = e.c.read(goalsProvider).single;
        expect(saved.saved, 1300000);
        expect(saved.progress, closeTo(.13, .001));
        // Nov 2026 s/d Okt 2027 = 12 bulan.
        expect(saved.monthlyNeeded(today), closeTo(8700000 / 12, .01));
        expect(saved.savedIn(DateTime(2026, 11)), 1300000);

        final txs = e.c.read(transactionsProvider);
        expect(txs.map((t) => t.category), [
          TransactionCategory.savingsWithdrawal,
          TransactionCategory.savings,
        ]);
        expect(e.c.read(balanceProvider), -800000);

        final setor = saved.deposits.last;
        await goals.removeDeposit(g.id, setor.id);
        expect(e.c.read(goalsProvider).single.saved, 300000);
        expect(e.c.read(transactionsProvider), hasLength(1));
      },
    );
  });

  group('backup', () {
    test(
      'ekspor lalu pulihkan ke HP "baru" mengembalikan semua data',
      () async {
        final a = _env(
          transactions: [tx('t1', 50000, TransactionCategory.food)],
        );
        final arisan = await a.c
            .read(customCategoriesProvider.notifier)
            .add(
              label: 'Arisan',
              type: TransactionType.expense,
              iconKey: 'family',
              color: Colors.purple,
            );
        await a.c
            .read(transactionsProvider.notifier)
            .add(
              title: 'Arisan',
              amount: 100000,
              type: TransactionType.expense,
              category: arisan,
              date: DateTime(2026, 11, 2),
            );
        await a.c.read(budgetLimitsProvider.notifier).setLimit('food', 2000000);
        await a.c
            .read(goalsProvider.notifier)
            .add(
              name: 'Liburan',
              target: 5000000,
              iconKey: 'flight',
              colorValue: 1,
            );
        await a.stores.reminderSettings.save(
          const ReminderSettings(daysBefore: 3, budgetAlerts: false),
        );

        BackupService service(_Env e) => BackupService(
          transactions: e.tx,
          recurring: e.rec,
          categories: e.stores.categories,
          budgets: e.stores.budgets,
          goals: e.stores.goals,
          reminderSettings: e.stores.reminderSettings,
          wallets: e.stores.wallets,
        );
        final json = service(a).exportJson(today);

        final b = _env();
        await b.rec.replaceAll(const []);
        final summary = service(b).inspect(json);
        expect(
          (
            summary.transactions,
            summary.categories,
            summary.budgets,
            summary.goals,
          ),
          (2, 1, 1, 1),
        );
        await service(b).restore(json);

        expect(b.tx.getAll(), hasLength(2));
        expect(b.rec.getAll().single.id, 'listrik');
        expect(b.stores.categories.getAll().single.label, 'Arisan');
        expect(b.stores.budgets.getLimits(), {'food': 2000000});
        expect(b.stores.goals.getAll().single.name, 'Liburan');
        expect(b.stores.reminderSettings.load().daysBefore, 3);
        // Kategori buatan sendiri terhubung kembali setelah dimuat.
        expect(b.c.read(transactionsProvider).first.category.label, 'Arisan');
      },
    );

    test('file tidak valid ditolak dengan pesan jelas', () {
      final s = BackupService(
        transactions: InMemoryTransactionRepository(),
        recurring: InMemoryRecurringRepository(),
        categories: InMemoryCategoryRepository(),
        budgets: InMemoryBudgetRepository(),
        goals: InMemoryGoalRepository(),
        reminderSettings: InMemoryReminderSettingsRepository(),
        wallets: InMemoryWalletRepository(),
      );
      expect(
        () => s.inspect('bukan json'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'File bukan backup yang valid.',
          ),
        ),
      );
      expect(
        () => s.inspect('{"app":"lain"}'),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => s.inspect('{"app":"keuangan_rumah_tangga","version":99}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('CSV memakai ; dan meng-escape isi', () {
      final csv = BackupService.transactionsCsv([
        Transaction(
          id: '1',
          title: 'Bakso; "enak"',
          amount: 25000,
          type: TransactionType.expense,
          category: TransactionCategory.food,
          date: DateTime(2026, 11, 3),
        ),
      ]);
      expect(csv.split('\n'), [
        'Tanggal;Jenis;Kategori;Judul;Nominal',
        '2026-11-03;Pengeluaran;Makanan;"Bakso; ""enak""";25000',
      ]);
    });
  });

  group('kunci aplikasi', () {
    test(
      'PIN di-hash, verifikasi, dan terkunci lagi setelah 30 detik',
      () async {
        var now = today;
        final e = _env(clock: () => now);
        await e.c.read(securityProvider.notifier).setPin('1234');
        final s = e.stores.security.load();
        expect(s.pinHash, isNot(contains('1234')));
        expect(s.verify('1234'), isTrue);
        expect(s.verify('4321'), isFalse);
        expect(SecuritySettings.withPin('1234').salt, isNot(s.salt));

        final lock = e.c.read(appLockedProvider.notifier);
        expect(lock.unlockWithPin('0000'), isFalse);
        expect(lock.unlockWithPin('1234'), isTrue);
        expect(e.c.read(appLockedProvider), isFalse);

        lock.onBackground();
        now = now.add(const Duration(seconds: 10));
        lock.onForeground();
        expect(e.c.read(appLockedProvider), isFalse);

        lock.onBackground();
        now = now.add(const Duration(seconds: 31));
        lock.onForeground();
        expect(e.c.read(appLockedProvider), isTrue);

        e.stores.biometric.succeed = true;
        expect(await lock.unlockWithBiometric(), isTrue);
        expect(e.c.read(appLockedProvider), isFalse);
      },
    );
  });

  group('notifikasi', () {
    test('izin mati → pengingat terkirim tidak dicatat ke riwayat', () async {
      var now = today;
      final e = _env(clock: () => now);
      final inbox = e.c.read(notificationInboxProvider.notifier);
      await inbox.syncSchedule(e.c.read(plannedRemindersProvider));
      e.notif.granted = false;
      now = DateTime(2026, 11, 4, 9);
      await inbox.collectDelivered();
      expect(e.c.read(notificationInboxProvider), isEmpty);
      expect(e.log.scheduled, hasLength(2));
    });

    test('payload notifikasi bolak-balik & tandai dibaca', () async {
      var now = today;
      final e = _env(clock: () => now);
      final plan = e.c.read(plannedRemindersProvider);
      final p = PlannedReminder.parsePayload(plan.first.payload)!;
      expect((p.recurringId, p.dueDate), ('listrik', DateTime(2026, 11, 5)));
      expect(PlannedReminder.parsePayload('rusak'), isNull);

      final inbox = e.c.read(notificationInboxProvider.notifier);
      await inbox.syncSchedule(plan);
      now = DateTime(2026, 11, 4, 9);
      await inbox.markReadByPayload(plan.first.payload);
      expect(e.c.read(notificationInboxProvider).single.read, isTrue);
    });
  });
}
