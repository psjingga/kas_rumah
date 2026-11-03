import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:keuangan_rumah_tangga/app/app.dart';
import 'package:keuangan_rumah_tangga/features/reminders/domain/entities/notification_entry.dart';
import 'package:keuangan_rumah_tangga/features/transactions/domain/entities/transaction.dart';

import 'fakes.dart';

Future<InMemoryTransactionRepository> _pumpApp(
  WidgetTester tester, {
  List<Transaction> initial = const [],
  InMemoryRecurringRepository? recurring,
  FakeNotificationService? notifications,
  InMemoryNotificationLogRepository? notificationLog,
}) async {
  // Layar selebar HP (393 dp) tapi sangat tinggi, agar seluruh isi
  // dashboard (grafik + riwayat) terbangun tanpa perlu scroll.
  tester.view
    ..physicalSize = const Size(1080, 7000)
    ..devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);

  final repo = InMemoryTransactionRepository(initial);
  await tester.pumpWidget(
    ProviderScope(
      overrides: testOverrides(repo, recurring, notifications, notificationLog),
      child: const KeuanganApp(),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

/// Pindah tab lewat navigasi bawah.
Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

/// Buka halaman Transaksi Rutin lewat tab Lainnya.
Future<void> _openRecurring(WidgetTester tester) async {
  await _tab(tester, 'Lainnya');
  await tester.tap(find.text('Transaksi Rutin'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('dashboard menampilkan saldo dan legenda pie chart', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      initial: [
        tx('1', 5000000, TransactionCategory.salary),
        tx('2', 750000, TransactionCategory.bills),
      ],
    );

    expect(find.text('Rp 4.250.000'), findsOneWidget); // saldo
    expect(find.text('Rp 5.000.000'), findsWidgets); // pemasukan
    expect(find.text('Pemasukan vs Pengeluaran'), findsOneWidget);
    expect(find.text('87.0%'), findsOneWidget); // legenda pemasukan
    expect(find.text('13.0%'), findsOneWidget); // legenda pengeluaran
    expect(find.text('15%'), findsOneWidget); // terpakai 750rb dari 5jt
  });

  testWidgets('form memvalidasi input lalu menyimpan transaksi', (
    tester,
  ) async {
    final repo = await _pumpApp(tester);
    expect(find.text('Belum ada transaksi.'), findsOneWidget);
    expect(find.text('November 2026'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // Kosong → dua pesan wajib.
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    expect(find.text('Judul wajib diisi'), findsOneWidget);
    expect(find.text('Nominal wajib diisi'), findsOneWidget);

    // Huruf dibuang formatter; 0 ditolak.
    final nominal = find.widgetWithText(TextFormField, 'Nominal');
    await tester.enterText(nominal, 'abc');
    expect(find.text('abc'), findsNothing);
    await tester.enterText(nominal, '0');
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    expect(find.text('Nominal harus lebih dari 0'), findsOneWidget);

    // Isi benar → tersimpan dengan pemisah ribuan.
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Judul / Deskripsi'),
      'Makan siang',
    );
    await tester.enterText(nominal, '85000');
    expect(find.text('85.000'), findsOneWidget);
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Transaksi tersimpan.'), findsOneWidget);
    final saved = repo.getAll().single;
    expect(saved.amount, 85000);
    expect(saved.category, TransactionCategory.food);
    expect(find.text('-Rp 85.000'), findsOneWidget); // saldo negatif
    await _tab(tester, 'Riwayat');
    expect(find.text('Makan siang'), findsOneWidget);
  });

  testWidgets('ganti ke Pemasukan menampilkan kategori pemasukan', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pemasukan').last);
    await tester.pumpAndSettle();
    expect(find.text('Gaji'), findsOneWidget);
    expect(find.text('Makanan'), findsNothing);
  });

  testWidgets('geser untuk hapus, lalu urungkan', (tester) async {
    final repo = await _pumpApp(
      tester,
      initial: [tx('1', 20000, TransactionCategory.transport)],
    );

    await _tab(tester, 'Riwayat');
    await tester.drag(find.text('Transaksi 1'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(repo.getAll(), isEmpty);
    expect(find.text('"Transaksi 1" dihapus.'), findsOneWidget);

    await tester.tap(find.text('Urungkan'));
    await tester.pumpAndSettle();
    expect(repo.getAll(), hasLength(1));
    expect(find.text('Transaksi 1'), findsOneWidget);
  });

  testWidgets('ketuk transaksi untuk mengubah nominal', (tester) async {
    final repo = await _pumpApp(
      tester,
      initial: [tx('1', 20000, TransactionCategory.transport)],
    );
    await _tab(tester, 'Riwayat');
    await tester.tap(find.text('Transaksi 1'));
    await tester.pumpAndSettle();
    expect(find.text('Ubah Transaksi'), findsOneWidget);
    expect(find.text('20.000'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nominal'),
      '25000',
    );
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(repo.getAll().single.amount, 25000);
    expect(find.text('− Rp 25.000'), findsOneWidget);
  });

  group('transaksi rutin', () {
    testWidgets('catat dengan nominal default dari kartu rutin', (
      tester,
    ) async {
      final repo = await _pumpApp(
        tester,
        recurring: InMemoryRecurringRepository([listrik()]),
      );
      expect(find.text('Rutin bulan ini'), findsOneWidget);
      expect(find.text('1 belum dicatat'), findsOneWidget);

      await tester.tap(find.byTooltip('Catat Listrik'));
      await tester.pumpAndSettle();
      expect(find.text('Rutin bulan ini'), findsNothing);
      expect(repo.getAll().single.date, DateTime(2026, 11, 5));
      expect(find.text('-Rp 450.000'), findsOneWidget); // saldo
    });

    testWidgets('ubah nominal bulan ini & jadikan default', (tester) async {
      final recurring = InMemoryRecurringRepository([listrik()]);
      final repo = await _pumpApp(tester, recurring: recurring);

      await tester.tap(find.text('Listrik'));
      await tester.pumpAndSettle();
      expect(find.text('Catat November 2026'), findsOneWidget);
      expect(find.text('450.000'), findsOneWidget); // terisi default

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nominal'),
        '520000',
      );
      await tester.tap(find.text('Jadikan nominal default'));
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      final t = repo.getAll().single;
      expect(t.amount, 520000);
      expect(t.recurringId, 'listrik');
      expect(recurring.getAll().single.amount, 520000);
    });

    testWidgets('transaksi baru "Ulangi tiap bulan" muncul di bulan depan', (
      tester,
    ) async {
      final recurring = InMemoryRecurringRepository();
      await _pumpApp(tester, recurring: recurring);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Judul / Deskripsi'),
        'Internet',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nominal'),
        '350000',
      );
      await tester.tap(find.text('Ulangi tiap bulan'));
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      final r = recurring.getAll().single;
      expect((r.amount, r.dayOfMonth), (350000, 3));
      // Bulan ini sudah tercatat, jadi tidak ada kartu rutin.
      expect(find.text('Rutin bulan ini'), findsNothing);

      await tester.tap(find.byTooltip('Bulan berikutnya'));
      await tester.pumpAndSettle();
      expect(find.text('Desember 2026'), findsOneWidget);
      expect(find.text('Ke bulan ini'), findsOneWidget);
      expect(find.text('Rutin bulan ini'), findsOneWidget);
      expect(find.text('Internet'), findsOneWidget);
      await _tab(tester, 'Riwayat');
      expect(find.text('Belum ada transaksi di bulan ini.'), findsOneWidget);
    });

    testWidgets('kelola transaksi rutin: ubah nominal default', (tester) async {
      final recurring = InMemoryRecurringRepository([listrik()]);
      await _pumpApp(tester, recurring: recurring);

      await _openRecurring(tester);
      expect(find.text('Tiap tgl 5 · Tagihan'), findsOneWidget);

      await tester.tap(find.text('Listrik'));
      await tester.pumpAndSettle();
      expect(find.text('Ubah Rutin'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nominal default'),
        '600000',
      );
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      expect(recurring.getAll().single.amount, 600000);
      expect(find.text('− Rp 600.000'), findsOneWidget);
    });
  });

  testWidgets('dashboard: sisa bulan lalu, rincian kategori, tren', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      initial: [
        tx(
          'okt',
          1000000,
          TransactionCategory.salary,
          date: DateTime(2026, 10, 2),
        ),
        tx('makan', 300000, TransactionCategory.food),
        tx('bensin', 100000, TransactionCategory.transport),
      ],
    );
    // Sisa bulan lalu hanya ditampilkan, tidak ditambahkan ke saldo.
    expect(find.text('Sisa Saldo'), findsOneWidget);
    expect(find.text('-Rp 400.000'), findsOneWidget);
    expect(find.text('Sisa bulan lalu Rp 1.000.000'), findsOneWidget);

    expect(find.text('Pengeluaran per Kategori'), findsOneWidget);
    expect(find.text('Makanan'), findsOneWidget);
    expect(find.text('75.0%'), findsOneWidget);

    expect(find.text('Tren 6 Bulan'), findsOneWidget);
    expect(find.text('Okt'), findsOneWidget);
    expect(find.text('Nov'), findsOneWidget);
  });

  testWidgets('cari transaksi di semua bulan dengan filter', (tester) async {
    await _pumpApp(
      tester,
      initial: [
        tx(
          'gaji',
          5000000,
          TransactionCategory.salary,
          date: DateTime(2026, 9, 25),
        ),
        tx('listrik', 450000, TransactionCategory.bills),
        tx('makan', 30000, TransactionCategory.food),
      ],
    );
    await tester.tap(find.byTooltip('Cari transaksi'));
    await tester.pumpAndSettle();
    expect(
      find.text('3 transaksi · Masuk Rp 5.000.000 · Keluar Rp 480.000'),
      findsOneWidget,
    );
    expect(find.text('September 2026'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'listrik');
    await tester.pump();
    expect(find.text('Transaksi listrik'), findsOneWidget);
    expect(find.text('Transaksi makan'), findsNothing);

    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Pemasukan'));
    await tester.pump();
    expect(find.text('Transaksi gaji'), findsOneWidget);
    expect(find.text('Transaksi listrik'), findsNothing);
    // Chip kategori hanya kategori pemasukan.
    expect(find.widgetWithText(FilterChip, 'Makanan'), findsNothing);
    expect(find.widgetWithText(FilterChip, 'Gaji'), findsOneWidget);
  });

  testWidgets('pengaturan pengingat: jadwal, matikan, uji', (tester) async {
    final notifications = FakeNotificationService();
    await _pumpApp(
      tester,
      recurring: InMemoryRecurringRepository([listrik()]),
      notifications: notifications,
    );
    await _openRecurring(tester);
    await tester.tap(find.byTooltip('Pengaturan pengingat'));
    await tester.pumpAndSettle();

    expect(find.text('H-1'), findsOneWidget);
    expect(find.text('08.00'), findsOneWidget);
    expect(find.text('Tagihan rutin: Listrik'), findsNWidgets(3));
    expect(find.text('Rab, 4 Nov 2026 · 08.00'), findsOneWidget);

    await tester.tap(find.text('Kirim notifikasi uji'));
    await tester.pump();
    expect(notifications.shown, ['Uji pengingat']);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(find.text('Pengingat dimatikan.'), findsOneWidget);

    final asked = notifications.permissionRequests;
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(notifications.permissionRequests, asked + 1);
    expect(find.text('Tagihan rutin: Listrik'), findsNWidgets(3));
  });

  testWidgets('halaman notifikasi: badge, status, catat dari notifikasi', (
    tester,
  ) async {
    final log = InMemoryNotificationLogRepository([
      NotificationEntry(
        id: 'n1',
        title: 'Tagihan rutin: Listrik',
        body: 'Jatuh tempo besok (5 Nov 2026) · Rp 450.000.',
        time: DateTime(2026, 11, 2, 8),
        recurringId: 'listrik',
        dueDate: DateTime(2026, 11, 5),
      ),
    ]);
    final repo = await _pumpApp(
      tester,
      recurring: InMemoryRecurringRepository([listrik()]),
      notificationLog: log,
    );
    // Badge lonceng menampilkan 1 belum dibaca.
    expect(
      find.descendant(of: find.byType(Badge), matching: find.text('1')),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Notifikasi'));
    await tester.pumpAndSettle();
    expect(find.text('Tagihan rutin: Listrik'), findsOneWidget);
    expect(find.text('Belum dicatat'), findsOneWidget);
    expect(find.text('Sen, 2 Nov 2026 · 08.00'), findsOneWidget);

    // Ketuk → langsung ke form catat, simpan.
    await tester.tap(find.text('Tagihan rutin: Listrik'));
    await tester.pumpAndSettle();
    expect(find.text('Catat November 2026'), findsOneWidget);
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(repo.getAll().single.recurringId, 'listrik');
    expect(find.text('Sudah dicatat'), findsOneWidget);
    expect(log.inbox.single.read, isTrue);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.byType(Badge), findsOneWidget);
    expect(
      find.descendant(of: find.byType(Badge), matching: find.text('1')),
      findsNothing,
    );
  });

  testWidgets('notifikasi uji tercatat di riwayat', (tester) async {
    final log = InMemoryNotificationLogRepository();
    await _pumpApp(tester, notificationLog: log);
    await tester.tap(find.byTooltip('Notifikasi'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada notifikasi.'), findsOneWidget);

    await tester.tap(find.byTooltip('Pengaturan pengingat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kirim notifikasi uji'));
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.text('Uji pengingat'), findsOneWidget);
  });
}
