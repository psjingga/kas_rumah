import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/navigation/home_tab.dart';
import '../../../../core/theme/money_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/month.dart';
import '../../../../core/utils/share_file.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../transactions/domain/entities/finance_summary.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../../transactions/presentation/widgets/category_breakdown_card.dart';
import '../../../transactions/presentation/widgets/month_selector.dart';
import '../../../transactions/presentation/widgets/monthly_trend_chart.dart';
import '../../../transactions/presentation/widgets/transaction_actions.dart';
import '../../../wallets/presentation/providers/wallet_providers.dart';
import '../../data/report_pdf.dart';
import '../providers/report_providers.dart';

/// Buka bulan [month] di tab Ringkasan (dari laporan).
void _openMonth(BuildContext context, WidgetRef ref, DateTime month) {
  ref.read(selectedMonthProvider.notifier).select(month);
  ref.read(homeTabProvider.notifier).select(HomeTab.summary);
  Navigator.of(context).popUntil((r) => r.isFirst);
}

/// Laporan: tahunan, perbandingan dua bulan, dan laporan bulanan yang bisa
/// dibagikan sebagai gambar/PDF.
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Laporan'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Tahunan'),
              Tab(text: 'Bandingkan'),
              Tab(text: 'Bulanan'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_YearTab(), _CompareTab(), _MonthlyTab()],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tahunan

class _YearTab extends ConsumerWidget {
  const _YearTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(yearReportProvider);
    final year = ref.read(reportYearProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final busiest = r.busiestMonth;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Tahun sebelumnya',
              onPressed: year.previous,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${r.year}',
                textAlign: TextAlign.center,
                style: textTheme.titleMedium,
              ),
            ),
            IconButton(
              tooltip: 'Tahun berikutnya',
              onPressed: year.next,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if (r.activeMonths.isEmpty)
          const EmptyState(
            icon: Icons.bar_chart,
            title: 'Belum ada transaksi di tahun ini',
          )
        else ...[
          // Angka utama setahun.
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: [
              _Stat(
                'Total pemasukan',
                Fmt.rupiah(r.totalIncome),
                color: context.incomeColor,
              ),
              _Stat(
                'Total pengeluaran',
                Fmt.rupiah(r.totalExpense),
                color: context.expenseColor,
              ),
              _Stat(
                'Sisa setahun',
                Fmt.rupiah(r.net),
                color: r.net < 0 ? context.expenseColor : null,
              ),
              _Stat(
                'Rasio menabung',
                '${(r.savingsRate * 100).round()}%',
                caption: 'pemasukan yang tersisa',
              ),
              _Stat(
                'Rata-rata keluar/bulan',
                Fmt.rupiah(r.averageMonthlyExpense),
                caption: 'dari ${r.activeMonths.length} bulan berdata',
              ),
              if (busiest != null)
                _Stat(
                  'Bulan paling boros',
                  Fmt.monthName(busiest.month),
                  caption: Fmt.rupiah(busiest.expense),
                  color: context.expenseColor,
                ),
            ],
          ),
          const SizedBox(height: 12),
          MonthlyTrendChart(
            title: 'Pemasukan & Pengeluaran ${r.year}',
            trend: r.months,
            selectedMonth: DateTime(0),
            onSelectMonth: (m) => _openMonth(context, ref, m),
          ),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Bulan', style: textTheme.labelMedium),
                      ),
                      SizedBox(
                        width: 80,
                        child: Text(
                          'Masuk',
                          textAlign: TextAlign.right,
                          style: textTheme.labelMedium,
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: Text(
                          'Keluar',
                          textAlign: TextAlign.right,
                          style: textTheme.labelMedium,
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: Text(
                          'Sisa',
                          textAlign: TextAlign.right,
                          style: textTheme.labelMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                for (final m in r.activeMonths)
                  InkWell(
                    onTap: () => _openMonth(context, ref, m.month),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(Fmt.shortMonth(m.month))),
                          _Num(m.income),
                          _Num(m.expense),
                          _Num(
                            m.income - m.expense,
                            color: m.income - m.expense < 0
                                ? context.expenseColor
                                : context.incomeColor,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CategoryBreakdownCard(
            summary: FinanceSummary(
              totalIncome: r.totalIncome,
              totalExpense: r.totalExpense,
              expenseByCategory: r.expenseByCategory,
            ),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.caption, this.color});

  final String label;
  final String value;
  final String? caption;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: textTheme.bodySmall, maxLines: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
            if (caption case final c?)
              Text(
                c,
                style: textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
      ),
    );
  }
}

/// Angka ringkas rata kanan untuk tabel (mis. "1,5 jt").
class _Num extends StatelessWidget {
  const _Num(this.value, {this.color});

  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Text(
        value == 0 ? '–' : Fmt.compact(value),
        textAlign: TextAlign.right,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bandingkan

class _CompareTab extends ConsumerWidget {
  const _CompareTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(monthComparisonProvider);
    final months = ref.read(comparedMonthsProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    Widget picker(DateTime value, ValueChanged<DateTime> onChanged) => Card(
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Bulan sebelumnya',
            onPressed: () => onChanged(value.addMonths(-1)),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              DateFormat('MMM yyyy', 'id_ID').format(value),
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Bulan berikutnya',
            onPressed: () => onChanged(value.addMonths(1)),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );

    /// Sel perubahan; untuk pengeluaran naik = merah, untuk pemasukan &
    /// sisa naik = hijau.
    Widget change(double a, double b, {bool higherIsBad = true}) {
      final text = Fmt.change(a, b) ?? (b > 0 ? 'baru' : '–');
      final worse = higherIsBad ? b > a : b < a;
      return SizedBox(
        width: 56,
        child: Text(
          text,
          textAlign: TextAlign.right,
          style: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: a == b
                ? null
                : worse
                ? context.expenseColor
                : context.incomeColor,
          ),
        ),
      );
    }

    Widget row(
      String label,
      double a,
      double b, {
      bool higherIsBad = true,
      bool bold = false,
      Widget? leading,
    }) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          ?leading,
          if (leading != null) const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null,
            ),
          ),
          _Num(a),
          _Num(b),
          change(a, b, higherIsBad: higherIsBad),
        ],
      ),
    );

    Widget header() => Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          const Expanded(child: SizedBox.shrink()),
          for (final m in [c.first, c.second])
            SizedBox(
              width: 80,
              child: Text(
                Fmt.shortMonth(m),
                textAlign: TextAlign.right,
                style: textTheme.labelMedium,
              ),
            ),
          SizedBox(
            width: 56,
            child: Text(
              'Ubah',
              textAlign: TextAlign.right,
              style: textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );

    final a = c.firstSummary;
    final b = c.secondSummary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Expanded(child: picker(c.first, months.setFirst)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text('vs'),
            ),
            Expanded(child: picker(c.second, months.setSecond)),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              header(),
              row(
                'Pemasukan',
                a.totalIncome,
                b.totalIncome,
                higherIsBad: false,
              ),
              row('Pengeluaran', a.totalExpense, b.totalExpense),
              const Divider(height: 1),
              row(
                'Sisa saldo',
                a.balance,
                b.balance,
                higherIsBad: false,
                bold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('Pengeluaran per kategori', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        if (c.rows.isEmpty)
          const EmptyState(
            icon: Icons.compare_arrows,
            title: 'Belum ada pengeluaran di kedua bulan',
            compact: true,
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                header(),
                for (final r in c.rows)
                  row(
                    r.category.label,
                    r.first,
                    r.second,
                    leading: Icon(
                      r.category.icon,
                      size: 18,
                      color: r.category.color,
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(
          '▲ naik / ▼ turun dari ${Fmt.month(c.first)} ke '
          '${Fmt.month(c.second)}. Merah = lebih buruk, hijau = lebih baik.',
          style: textTheme.bodySmall,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bulanan (bagikan gambar / PDF)

class _MonthlyTab extends ConsumerStatefulWidget {
  const _MonthlyTab();

  @override
  ConsumerState<_MonthlyTab> createState() => _MonthlyTabState();
}

class _MonthlyTabState extends ConsumerState<_MonthlyTab> {
  final _reportKey = GlobalKey();
  var _busy = false;

  String get _monthSlug =>
      DateFormat('yyyy-MM').format(ref.read(selectedMonthProvider));

  Future<void> _run(Future<void> Function() task) async {
    setState(() => _busy = true);
    try {
      await task();
    } catch (e) {
      if (mounted) showAppSnack(context, 'Gagal membuat laporan: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Ambil gambar kartu laporan (PNG, 3x agar tajam).
  Future<void> _shareImage() => _run(() async {
    final boundary =
        _reportKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await shareFile(
      'laporan-kas-rumah-$_monthSlug.png',
      data!.buffer.asUint8List(),
      text: 'Laporan Kas Rumah ${Fmt.month(ref.read(selectedMonthProvider))}',
    );
  });

  Future<void> _sharePdf() => _run(() async {
    final month = ref.read(selectedMonthProvider);
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'),
    );
    final bytes = await buildMonthlyReportPdf(
      month: month,
      summary: ref.read(financeSummaryProvider),
      transactions: ref.read(monthTransactionsProvider),
      regular: regular,
      bold: bold,
      generatedAt: ref.read(clockProvider)(),
      walletNames: {for (final w in ref.read(walletsProvider)) w.id: w.name},
    );
    await shareFile(
      'laporan-kas-rumah-$_monthSlug.pdf',
      bytes,
      text: 'Laporan Kas Rumah ${Fmt.month(month)}',
    );
  });

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(selectedMonthProvider);
    final monthNotifier = ref.read(selectedMonthProvider.notifier);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        MonthSelector(
          month: month,
          isThisMonth: monthNotifier.isThisMonth,
          onPrevious: monthNotifier.previous,
          onNext: monthNotifier.next,
          onThisMonth: monthNotifier.goToThisMonth,
        ),
        RepaintBoundary(key: _reportKey, child: const MonthlyReportCard()),
        const SizedBox(height: 16),
        if (_busy) const LinearProgressIndicator(),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _shareImage,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Bagikan gambar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _sharePdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Bagikan PDF'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Gambar cocok untuk dikirim ke WhatsApp; PDF berisi daftar semua '
          'transaksi bulan ini dan bisa dicetak.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Kartu laporan bulanan yang ringkas, sekaligus sumber gambar yang
/// dibagikan.
class MonthlyReportCard extends ConsumerWidget {
  const MonthlyReportCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final s = ref.watch(financeSummaryProvider);
    final transactions = ref.watch(monthTransactionsProvider);
    final biggest = [
      for (final t in transactions)
        if (!t.isIncome) t,
    ]..sort((a, b) => b.amount.compareTo(a.amount));
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget stat(String label, double v, Color? color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.bodySmall),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Fmt.rupiah(v),
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dua baris agar tidak meluap di layar kecil.
            Row(
              children: [
                Icon(Icons.home_outlined, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Kas Rumah',
                  style: textTheme.labelLarge?.copyWith(color: scheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Laporan ${Fmt.month(month)}',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Divider(height: 20),
            Row(
              children: [
                stat('Pemasukan', s.totalIncome, context.incomeColor),
                stat('Pengeluaran', s.totalExpense, context.expenseColor),
                stat(
                  'Sisa',
                  s.balance,
                  s.balance < 0 ? context.expenseColor : scheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (s.expenseByCategory.isEmpty)
              Text('Belum ada pengeluaran.', style: textTheme.bodySmall)
            else ...[
              Text('Pengeluaran per kategori', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final MapEntry(key: c, value: v)
                  in s.expenseByCategory.entries.take(6))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(c.icon, size: 16, color: c.color),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 104,
                        child: Text(
                          c.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: s.shareOf(c),
                            minHeight: 6,
                            color: c.color,
                            backgroundColor: c.color.withValues(alpha: .12),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 84,
                        child: Text(
                          Fmt.rupiah(v),
                          textAlign: TextAlign.right,
                          style: textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (biggest.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Pengeluaran terbesar', style: textTheme.titleSmall),
              const SizedBox(height: 6),
              for (final t in biggest.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${t.title} · ${Fmt.date(t.date)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        Fmt.rupiah(t.amount),
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Text(
              '${transactions.length} transaksi',
              style: textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
