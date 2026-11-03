import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/formatters.dart';
import '../../transactions/domain/entities/finance_summary.dart';
import '../../transactions/domain/entities/transaction.dart';

const _teal = PdfColor.fromInt(0xFF00796B);
const _income = PdfColor.fromInt(0xFF2E7D32);
const _expense = PdfColor.fromInt(0xFFD32F2F);
const _muted = PdfColor.fromInt(0xFF6B7280);
const _line = PdfColor.fromInt(0xFFE5E7EB);

/// Buat PDF laporan bulanan (A4): ringkasan, pengeluaran per kategori, dan
/// daftar semua transaksi bulan itu.
///
/// [regular] & [bold] = font TTF (Plus Jakarta Sans) agar huruf/simbol
/// Indonesia (mis. "−", "·") tampil benar.
Future<Uint8List> buildMonthlyReportPdf({
  required DateTime month,
  required FinanceSummary summary,
  required List<Transaction> transactions,
  required pw.Font regular,
  required pw.Font bold,
  required DateTime generatedAt,
  Map<String, String> walletNames = const {},
}) {
  final doc = pw.Document(
    title: 'Laporan Kas Rumah ${Fmt.month(month)}',
    author: 'Kas Rumah',
  );
  final sorted = [...transactions]..sort((a, b) => a.date.compareTo(b.date));
  final dateFmt = DateFormat('d MMM', 'id_ID');

  pw.Widget stat(String label, double value, PdfColor color) => pw.Expanded(
    child: pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(color: _muted, fontSize: 9)),
          pw.SizedBox(height: 4),
          pw.Text(
            Fmt.rupiah(value),
            style: pw.TextStyle(font: bold, fontSize: 13, color: color),
          ),
        ],
      ),
    ),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      header: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        margin: const pw.EdgeInsets.only(bottom: 12),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _teal, width: 2)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Kas Rumah',
              style: pw.TextStyle(font: bold, color: _teal, fontSize: 14),
            ),
            pw.Text(
              'Laporan Keuangan ${Fmt.month(month)}',
              style: pw.TextStyle(font: bold, fontSize: 14),
            ),
          ],
        ),
      ),
      footer: (ctx) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Dibuat ${Fmt.dateTime(generatedAt)}',
            style: const pw.TextStyle(color: _muted, fontSize: 8),
          ),
          pw.Text(
            'Halaman ${ctx.pageNumber} dari ${ctx.pagesCount}',
            style: const pw.TextStyle(color: _muted, fontSize: 8),
          ),
        ],
      ),
      build: (ctx) => [
        // Ringkasan.
        pw.Row(
          children: [
            stat('Pemasukan', summary.totalIncome, _income),
            pw.SizedBox(width: 8),
            stat('Pengeluaran', summary.totalExpense, _expense),
            pw.SizedBox(width: 8),
            stat(
              'Sisa saldo',
              summary.balance,
              summary.balance < 0 ? _expense : _teal,
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          '${transactions.length} transaksi · Sisa bulan lalu '
          '${Fmt.rupiah(summary.previousMonthBalance)}',
          style: const pw.TextStyle(color: _muted, fontSize: 9),
        ),
        pw.SizedBox(height: 18),

        // Pengeluaran per kategori dengan bar porsi.
        pw.Text(
          'Pengeluaran per kategori',
          style: pw.TextStyle(font: bold, fontSize: 12),
        ),
        pw.SizedBox(height: 8),
        if (summary.expenseByCategory.isEmpty)
          pw.Text(
            'Belum ada pengeluaran.',
            style: const pw.TextStyle(color: _muted),
          )
        else
          for (final MapEntry(key: c, value: amount)
              in summary.expenseByCategory.entries)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Row(
                children: [
                  pw.SizedBox(
                    width: 130,
                    child: pw.Text(
                      c.label,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Stack(
                      children: [
                        pw.Container(height: 8, color: _line),
                        pw.LayoutBuilder(
                          builder: (ctx, constraints) => pw.Container(
                            height: 8,
                            width:
                                (constraints?.maxWidth ?? 0) *
                                summary.shareOf(c),
                            color: PdfColor.fromInt(c.color.toARGB32()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(
                    width: 40,
                    child: pw.Text(
                      '${(summary.shareOf(c) * 100).toStringAsFixed(1)}%',
                      textAlign: pw.TextAlign.right,
                      style: const pw.TextStyle(fontSize: 9, color: _muted),
                    ),
                  ),
                  pw.SizedBox(
                    width: 90,
                    child: pw.Text(
                      Fmt.rupiah(amount),
                      textAlign: pw.TextAlign.right,
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
        pw.SizedBox(height: 18),

        // Daftar transaksi.
        pw.Text(
          'Daftar transaksi',
          style: pw.TextStyle(font: bold, fontSize: 12),
        ),
        pw.SizedBox(height: 8),
        if (sorted.isEmpty)
          pw.Text(
            'Belum ada transaksi.',
            style: const pw.TextStyle(color: _muted),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: ['Tanggal', 'Judul', 'Kategori', 'Dompet', 'Nominal'],
            data: [
              for (final t in sorted)
                [
                  dateFmt.format(t.date),
                  t.note.isEmpty ? t.title : '${t.title}\n${t.note}',
                  t.category.label,
                  walletNames[t.walletId ?? 'main'] ?? '',
                  Fmt.signed(t.signedAmount),
                ],
            ],
            headerStyle: pw.TextStyle(
              font: bold,
              fontSize: 9,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: _teal),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: {4: pw.Alignment.centerRight},
            columnWidths: {
              0: const pw.FixedColumnWidth(48),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(1.5),
              4: const pw.FixedColumnWidth(80),
            },
            oddRowDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF7FAF9),
            ),
            border: null,
          ),
      ],
    ),
  );
  return doc.save();
}
