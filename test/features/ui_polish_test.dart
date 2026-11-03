import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:keuangan_rumah_tangga/app/app.dart';
import 'package:keuangan_rumah_tangga/core/utils/formatters.dart';
import 'package:keuangan_rumah_tangga/features/transactions/domain/entities/transaction.dart';

import 'transactions/fakes.dart';

Future<(InMemoryTransactionRepository, InMemoryRecurringRepository)> _pump(
  WidgetTester tester, {
  List<Transaction> initial = const [],
  TestStores? stores,
}) async {
  tester.view
    ..physicalSize = const Size(1080, 7000)
    ..devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  final repo = InMemoryTransactionRepository(initial);
  final recurring = InMemoryRecurringRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: testOverrides(
        repo,
        recurring,
        null,
        null,
        null,
        stores ?? TestStores(),
      ),
      child: const KeuanganApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (repo, recurring);
}

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('format: judul hari & perubahan persen', () {
    final now = DateTime(2026, 11, 3, 9);
    expect(Fmt.dayHeader(DateTime(2026, 11, 3, 20), now), 'Hari ini');
    expect(Fmt.dayHeader(DateTime(2026, 11, 2), now), 'Kemarin');
    expect(Fmt.dayHeader(DateTime(2026, 10, 30), now), 'Jumat, 30 Okt');
    expect(Fmt.dayHeader(DateTime(2025, 12, 1), now), 'Senin, 1 Des 2025');
    expect(Fmt.change(100, 112), '▲12%');
    expect(Fmt.change(200, 190), '▼5%');
    expect(Fmt.change(0, 50), isNull);
    expect(Fmt.signed(-120000), '−Rp 120.000');
  });

  testWidgets('riwayat dikelompokkan per hari dengan total harian', (
    tester,
  ) async {
    await _pump(
      tester,
      initial: [
        tx('a', 50000, TransactionCategory.food, date: DateTime(2026, 11, 3)),
        tx(
          'b',
          20000,
          TransactionCategory.transport,
          date: DateTime(2026, 11, 3),
        ),
        tx(
          'c',
          1000000,
          TransactionCategory.salary,
          date: DateTime(2026, 11, 1),
        ),
      ],
    );
    await _tab(tester, 'Riwayat');
    expect(find.text('Hari ini'), findsOneWidget);
    expect(find.text('−Rp 70.000'), findsOneWidget);
    expect(find.text('Minggu, 1 Nov'), findsOneWidget);
    expect(find.text('+Rp 1.000.000'), findsOneWidget);
    // Tanggal tidak diulang di tiap baris.
    expect(find.text('Makanan'), findsOneWidget);
    expect(find.text('Makanan · 3 Nov 2026'), findsNothing);
  });

  testWidgets('form: saran judul dari riwayat & tombol nominal cepat', (
    tester,
  ) async {
    final (repo, _) = await _pump(
      tester,
      initial: [
        Transaction(
          id: 'old',
          title: 'Bensin',
          amount: 20000,
          type: TransactionType.expense,
          category: TransactionCategory.transport,
          date: DateTime(2026, 10, 20),
        ),
      ],
    );
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Judul / Deskripsi'),
      'ben',
    );
    await tester.pumpAndSettle();
    expect(find.text('Transportasi · Rp 20.000'), findsOneWidget);
    await tester.tap(find.text('Bensin'));
    await tester.pumpAndSettle();
    // Kategori & nominal terakhir ikut terisi.
    expect(find.text('20.000'), findsOneWidget);
    expect(find.text('Transportasi'), findsOneWidget);

    await tester.tap(find.text('+50rb'));
    await tester.tap(find.text('+10rb'));
    await tester.pump();
    expect(find.text('80.000'), findsOneWidget);

    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    final saved = repo.getAll().first;
    expect(
      (saved.title, saved.amount, saved.category),
      ('Bensin', 80000.0, TransactionCategory.transport),
    );
  });

  testWidgets('ringkasan: banding bulan lalu & kartu anggaran/tabungan', (
    tester,
  ) async {
    final stores = TestStores();
    stores.budgets.limits = {'food': 100000};
    await _pump(
      tester,
      stores: stores,
      initial: [
        tx('o', 100000, TransactionCategory.food, date: DateTime(2026, 10, 5)),
        tx('n', 85000, TransactionCategory.food, date: DateTime(2026, 11, 2)),
      ],
    );
    expect(find.text('▼15% vs bln lalu'), findsOneWidget);
    expect(find.text('▼15%'), findsOneWidget); // per kategori
    expect(find.text('1 hampir habis'), findsOneWidget);
    expect(find.text('Belum ada target'), findsOneWidget);

    // Ketuk kartu anggaran → pindah ke tab Anggaran.
    await tester.tap(find.text('1 hampir habis'));
    await tester.pumpAndSettle();
    expect(find.text('Total anggaran bulan ini'), findsOneWidget);
  });

  testWidgets('ringkasan: geser untuk pindah bulan', (tester) async {
    await _pump(tester);
    expect(find.text('November 2026'), findsOneWidget);
    await tester.fling(find.text('Sisa Saldo'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Desember 2026'), findsOneWidget);
  });

  testWidgets('tampilan kosong punya tombol aksi', (tester) async {
    await _pump(tester);
    await _tab(tester, 'Anggaran');
    expect(find.text('Belum ada anggaran'), findsOneWidget);
    await tester.tap(find.text('Atur anggaran'));
    await tester.pumpAndSettle();
    expect(find.text('Pilih kategori pengeluaran'), findsOneWidget);
  });

  testWidgets('halaman pembuka: isi gaji & tagihan lalu masuk', (tester) async {
    final stores = TestStores();
    stores.preferences.onboardingDone = false;
    final (_, recurring) = await _pump(tester, stores: stores);

    expect(find.text('Selamat datang di Kas Rumah'), findsOneWidget);
    await tester.tap(find.text('Mulai'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Nominal per bulan'),
      '8000000',
    );
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Listrik'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nominal per bulan'),
      '450000',
    );
    await tester.tap(find.text('Tambahkan'));
    await tester.pumpAndSettle();
    expect(find.text('Rp 450.000 · tiap tgl 5'), findsOneWidget);
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nanti saja, mulai pakai'));
    await tester.pumpAndSettle();

    expect(stores.preferences.onboardingDone, isTrue);
    expect(recurring.getAll().map((r) => (r.title, r.amount, r.dayOfMonth)), [
      ('Listrik', 450000.0, 5),
      ('Gaji', 8000000.0, 25),
    ]);
    // Masuk ke halaman utama; tagihan muncul di kartu rutin.
    expect(find.text('Rutin bulan ini'), findsOneWidget);
  });

  testWidgets('pengguna lama (sudah ada data) tidak melihat halaman pembuka', (
    tester,
  ) async {
    final stores = TestStores();
    stores.preferences.onboardingDone = false;
    await _pump(
      tester,
      stores: stores,
      initial: [tx('a', 1000, TransactionCategory.food)],
    );
    expect(find.text('Selamat datang di Kas Rumah'), findsNothing);
    expect(find.text('Sisa Saldo'), findsOneWidget);
  });
}
