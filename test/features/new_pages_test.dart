import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:keuangan_rumah_tangga/app/app.dart';
import 'package:keuangan_rumah_tangga/features/settings/domain/security.dart';
import 'package:keuangan_rumah_tangga/features/transactions/domain/entities/transaction.dart';

import 'transactions/fakes.dart';

Future<(InMemoryTransactionRepository, TestStores)> _pump(
  WidgetTester tester, {
  List<Transaction> initial = const [],
  TestStores? stores,
}) async {
  tester.view
    ..physicalSize = const Size(1080, 7000)
    ..devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  final repo = InMemoryTransactionRepository(initial);
  final s = stores ?? TestStores();
  await tester.pumpWidget(
    ProviderScope(
      overrides: testOverrides(repo, null, null, null, null, s),
      child: const KeuanganApp(),
    ),
  );
  await tester.pumpAndSettle();
  return (repo, s);
}

Future<void> _tab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  testWidgets('anggaran: tambah lewat tombol, progres & ubah', (tester) async {
    final (_, stores) = await _pump(
      tester,
      initial: [tx('a', 2550000, TransactionCategory.food)],
    );
    await _tab(tester, 'Anggaran');
    expect(find.textContaining('Belum ada anggaran'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Makanan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '3000000');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(stores.budgets.limits, {'food': 3000000});
    expect(find.text('85%'), findsOneWidget);
    expect(
      find.text('Rp 2.550.000 dari Rp 3.000.000 · sisa Rp 450.000'),
      findsOneWidget,
    );

    // Ketuk untuk menghapus anggaran.
    await tester.tap(find.text('Makanan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(stores.budgets.limits, isEmpty);
  });

  testWidgets('tabungan: buat target, setor tercatat sebagai transaksi', (
    tester,
  ) async {
    final (repo, stores) = await _pump(tester);
    await _tab(tester, 'Tabungan');
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nama target'),
      'Dana darurat',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Target nominal'),
      '10000000',
    );
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Rp 0 dari Rp 10.000.000'), findsOneWidget);

    await tester.tap(find.text('Dana darurat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Setor'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '2500000');
    await tester.tap(find.widgetWithText(FilledButton, 'Setor').last);
    await tester.pumpAndSettle();

    expect(stores.goals.goals.single.saved, 2500000);
    expect(find.text('25%'), findsOneWidget);
    expect(repo.getAll().single.category, TransactionCategory.savings);
  });

  testWidgets('kategori: buat kategori sendiri lalu dipakai di form', (
    tester,
  ) async {
    final (repo, stores) = await _pump(tester);
    await _tab(tester, 'Lainnya');
    await tester.tap(find.text('Kategori'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Arisan');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(stores.categories.items.single.label, 'Arisan');
    expect(find.text('Arisan'), findsOneWidget);

    // Nama kembar ditolak.
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'makanan');
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    expect(find.text('Nama kategori sudah ada'), findsOneWidget);
  });

  testWidgets('kunci aplikasi: layar PIN menutupi aplikasi', (tester) async {
    final stores = TestStores();
    stores.security.settings = SecuritySettings.withPin('2580');
    await _pump(tester, stores: stores);

    expect(find.text('Masukkan PIN untuk membuka'), findsOneWidget);
    for (final d in ['1', '1', '1', '1']) {
      await tester.tap(find.text(d).last);
    }
    await tester.pump();
    expect(find.text('PIN salah (1×)'), findsOneWidget);

    for (final d in ['2', '5', '8', '0']) {
      await tester.tap(find.text(d).last);
    }
    await tester.pumpAndSettle();
    expect(find.text('Masukkan PIN untuk membuka'), findsNothing);
    expect(find.text('Sisa Saldo'), findsOneWidget);
  });

  testWidgets('lainnya: tema gelap & status backup', (tester) async {
    final (_, stores) = await _pump(tester);
    await _tab(tester, 'Lainnya');
    expect(find.text('Belum pernah backup'), findsOneWidget);

    await tester.tap(find.text('Gelap'));
    await tester.pumpAndSettle();
    expect(stores.preferences.themeMode, ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.text('Kategori'))).brightness,
      Brightness.dark,
    );
  });
}
