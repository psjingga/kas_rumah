import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/entities/finance_summary.dart';

const _incomeColor = Color(0xFF2E7D32);
const _expenseColor = Color(0xFFE53935);

/// Pie chart (donat) perbandingan pemasukan vs pengeluaran bulan terpilih.
/// Bagian tengah menampilkan berapa persen pemasukan yang sudah terpakai.
/// Ketuk irisan untuk menyorotnya.
class IncomeExpenseChart extends StatefulWidget {
  const IncomeExpenseChart({super.key, required this.summary});

  final FinanceSummary summary;

  @override
  State<IncomeExpenseChart> createState() => _IncomeExpenseChartState();
}

class _IncomeExpenseChartState extends State<IncomeExpenseChart> {
  /// Index irisan yang sedang disentuh; -1 = tidak ada.
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final total = s.totalIncome + s.totalExpense;
    final incomeShare = total == 0 ? 0.0 : s.totalIncome / total;
    final expenseShare = total == 0 ? 0.0 : s.totalExpense / total;
    final slices = [
      ('Pemasukan', s.totalIncome, incomeShare, _incomeColor),
      ('Pengeluaran', s.totalExpense, expenseShare, _expenseColor),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pemasukan vs Pengeluaran',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (total == 0)
              SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    'Belum ada transaksi.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              )
            else ...[
              SizedBox(
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 56,
                        startDegreeOffset: -90,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) => setState(() {
                            _touched =
                                event.isInterestedForInteractions &&
                                    response?.touchedSection != null
                                ? response!.touchedSection!.touchedSectionIndex
                                : -1;
                          }),
                        ),
                        sections: [
                          for (final (i, (_, value, share, color))
                              in slices.indexed)
                            // Irisan bernilai 0 tidak digambar.
                            if (value > 0)
                              PieChartSectionData(
                                value: value,
                                color: color,
                                radius: i == _touched ? 50 : 42,
                                title: share >= .06
                                    ? '${(share * 100).round()}%'
                                    : '',
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                        ],
                      ),
                    ),
                    _CenterLabel(summary: s),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              for (final (label, value, share, color) in slices)
                _LegendRow(
                  label: label,
                  amount: value,
                  share: share,
                  color: color,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tengah donat: persentase pemasukan yang terpakai untuk pengeluaran.
class _CenterLabel extends StatelessWidget {
  const _CenterLabel({required this.summary});

  final FinanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final textTheme = Theme.of(context).textTheme;
    final (value, label) = s.totalIncome == 0
        ? ('—', 'Tanpa pemasukan')
        : ('${(s.totalExpense / s.totalIncome * 100).round()}%', 'Terpakai');
    final over = s.totalExpense > s.totalIncome;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: over ? _expenseColor : null,
          ),
        ),
        Text(label, style: textTheme.bodySmall),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.label,
    required this.amount,
    required this.share,
    required this.color,
  });

  final String label;
  final double amount;
  final double share;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(
            '${(share * 100).toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 12),
          Text(
            Fmt.rupiah(amount),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
