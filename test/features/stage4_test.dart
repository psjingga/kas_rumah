import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:keuangan_rumah_tangga/app/app.dart';
import 'package:keuangan_rumah_tangga/features/backup/data/backup_crypto.dart';
import 'package:keuangan_rumah_tangga/features/reports/data/report_pdf.dart';
import 'package:keuangan_rumah_tangga/features/reports/domain/reports.dart';
import 'package:keuangan_rumah_tangga/features/transactions/domain/entities/finance_summary.dart';
import 'package:keuangan_rumah_tangga/features/transactions/domain/entities/transaction.dart';
import 'package:pdf/widgets.dart' as pw;

import 'transactions/fakes.dart';

final _data = [
  tx(
    'gaji-okt',
    9000000,
    TransactionCategory.salary,
    date: DateTime(2026, 10, 25),
  ),
  tx(
    'makan-okt',
    2000000,
    TransactionCategory.food,
    date: DateTime(2026, 10, 10),
  ),
  tx(
    'gaji-nov',
    9000000,
    TransactionCategory.salary,
    date: DateTime(2026, 11, 1),
  ),
  tx(
    'makan-nov',
    1500000,
    TransactionCategory.food,
    date: DateTime(2026, 11, 2),
  ),
  tx(
    'rumah-nov',
    5000000,
    TransactionCategory.bills,
    date: DateTime(2026, 11, 5),
  ),
  tx('lama', 777, TransactionCategory.food, date: DateTime(2025, 12, 1)),
];

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('laporan tahunan', () {
    final r = YearReport.from(_data, 2026);
    expect(r.months, hasLength(12));
    expect(r.activeMonths.map((m) => m.month.month), [10, 11]);
    expect(
      (r.totalIncome, r.totalExpense, r.net),
      (18000000.0, 8500000.0, 9500000.0),
    );
    expect(r.averageMonthlyExpense, 4250000);
    expect(r.savingsRate, closeTo(.5278, .0001));
    expect(r.busiestMonth!.month, DateTime(2026, 11));
    expect(r.expenseByCategory.keys, [
      TransactionCategory.bills,
      TransactionCategory.food,
    ]);
    expect(YearReport.from(_data, 2024).busiestMonth, isNull);
  });

  test('perbandingan dua bulan per kategori', () {
    final c = MonthComparison.from(
      _data,
      DateTime(2026, 10),
      DateTime(2026, 11, 20),
    );
    expect(c.second, DateTime(2026, 11));
    expect(c.firstSummary.totalExpense, 2000000);
    expect(c.secondSummary.totalExpense, 6500000);
    expect(c.rows.map((r) => (r.category, r.first, r.second)), [
      (TransactionCategory.bills, 0.0, 5000000.0),
      (TransactionCategory.food, 2000000.0, 1500000.0),
    ]);
  });

  group('backup terenkripsi', () {
    const crypto = BackupCrypto(iterations: 1000); // cepat untuk tes
    const plain = '{"app":"keuangan_rumah_tangga","version":3}';

    test('enkripsi lalu buka kembali', () async {
      final locked = await crypto.encrypt(plain, 'rahasia123');
      expect(BackupCrypto.isEncrypted(locked), isTrue);
      expect(BackupCrypto.isEncrypted(plain), isFalse);
      expect(locked, isNot(contains('version')));
      expect(await crypto.decrypt(locked, 'rahasia123'), plain);
      // Salt & nonce acak → hasil berbeda tiap kali.
      expect(await crypto.encrypt(plain, 'rahasia123'), isNot(locked));
    });

    test('kata sandi salah / isi diubah ditolak', () async {
      final locked = await crypto.encrypt(plain, 'rahasia123');
      expect(
        () => crypto.decrypt(locked, 'salah'),
        throwsA(isA<WrongPasswordException>()),
      );
      final m = jsonDecode(locked) as Map<String, dynamic>;
      final data = base64.decode(m['data'] as String)..[0] ^= 1;
      m['data'] = base64.encode(data);
      expect(
        () => crypto.decrypt(jsonEncode(m), 'rahasia123'),
        throwsA(isA<WrongPasswordException>()),
      );
    });
  });

  test('PDF laporan bulanan terbentuk', () async {
    pw.Font font(String w) => pw.Font.ttf(
      File(
        'assets/fonts/PlusJakartaSans-$w.ttf',
      ).readAsBytesSync().buffer.asByteData(),
    );
    final nov = _data.where((t) => t.date.month == 11 && t.date.year == 2026);
    final bytes = await buildMonthlyReportPdf(
      month: DateTime(2026, 11),
      summary: FinanceSummary.from(nov),
      transactions: nov.toList(),
      regular: font('Regular'),
      bold: font('Bold'),
      generatedAt: today,
    );
    expect(utf8.decode(bytes.sublist(0, 5), allowMalformed: true), '%PDF-');
    expect(bytes.length, greaterThan(2000));
  });

  group('UI laporan', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(1080, 7000)
        ..devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: testOverrides(InMemoryTransactionRepository(_data)),
          child: const KeuanganApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Laporan'));
      await tester.pumpAndSettle();
    }

    testWidgets('tahunan: angka utama, tabel bulan → buka bulan', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('2026'), findsOneWidget);
      expect(find.text('Rp 18.000.000'), findsOneWidget);
      expect(find.text('53%'), findsOneWidget); // rasio menabung
      expect(find.text('November'), findsOneWidget); // bulan paling boros
      await tester.tap(find.text('Okt').last);
      await tester.pumpAndSettle();
      // Kembali ke Ringkasan bulan Oktober.
      expect(find.text('Oktober 2026'), findsOneWidget);
      expect(find.text('Sisa Saldo'), findsOneWidget);
    });

    testWidgets('bandingkan: bulan lalu vs bulan ini', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Bandingkan'));
      await tester.pumpAndSettle();
      expect(find.text('Okt 2026'), findsOneWidget);
      expect(find.text('Nov 2026'), findsOneWidget);
      expect(find.text('Tagihan'), findsOneWidget);
      expect(find.text('baru'), findsOneWidget); // tagihan baru di Nov
      expect(find.text('▼25%'), findsOneWidget); // makanan turun
    });

    testWidgets('bulanan: kartu laporan siap dibagikan', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Bulanan'));
      await tester.pumpAndSettle();
      expect(find.text('Laporan November 2026'), findsOneWidget);
      expect(find.text('Pengeluaran terbesar'), findsOneWidget);
      expect(find.text('Bagikan PDF'), findsOneWidget);
      expect(find.text('Bagikan gambar'), findsOneWidget);
    });
  });
}
