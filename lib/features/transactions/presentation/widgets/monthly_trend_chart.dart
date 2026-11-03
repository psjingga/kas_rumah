import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/money_colors.dart';
import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../providers/transaction_providers.dart';

const _incomeColor = ChartColors.income;
const _expenseColor = ChartColors.expense;

/// Bar chart pemasukan (hijau) & pengeluaran (merah) 6 bulan terakhir.
/// Tahan batang untuk melihat nominal; ketuk untuk pindah ke bulan itu.
class MonthlyTrendChart extends StatelessWidget {
  const MonthlyTrendChart({
    super.key,
    required this.trend,
    required this.selectedMonth,
    required this.onSelectMonth,
    this.title = 'Tren 6 Bulan',
    this.action,
  });

  final String title;

  /// Tombol opsional di kanan judul (mis. "Laporan").
  final Widget? action;

  final List<MonthTotals> trend;
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onSelectMonth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxY = trend.fold(
      0.0,
      (m, t) => [m, t.income, t.expense].reduce((a, b) => a > b ? a : b),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 4),
            const Row(
              children: [
                _Legend(color: _incomeColor, label: 'Masuk'),
                SizedBox(width: 12),
                _Legend(color: _expenseColor, label: 'Keluar'),
              ],
            ),
            const SizedBox(height: 16),
            if (maxY == 0)
              SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    'Belum ada data 6 bulan terakhir.',
                    style: TextStyle(color: theme.colorScheme.outline),
                  ),
                ),
              )
            else
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    maxY: maxY * 1.15,
                    alignment: BarChartAlignment.spaceAround,
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      horizontalInterval: maxY / 3,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: theme.colorScheme.outlineVariant,
                        strokeWidth: .6,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 44,
                          interval: maxY / 3,
                          getTitlesWidget: (value, meta) => value == meta.max
                              ? const SizedBox.shrink()
                              : SideTitleWidget(
                                  meta: meta,
                                  child: Text(
                                    Fmt.compact(value),
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final month = trend[value.toInt()].month;
                            final selected = month == selectedMonth;
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                Fmt.shortMonth(month),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w400,
                                  color: selected
                                      ? theme.colorScheme.primary
                                      : null,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      touchCallback: (event, response) {
                        final spot = response?.spot;
                        if (event is FlTapUpEvent && spot != null) {
                          onSelectMonth(trend[spot.touchedBarGroupIndex].month);
                        }
                      },
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) =>
                            theme.colorScheme.inverseSurface,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                            BarTooltipItem(
                              Fmt.rupiah(rod.toY),
                              TextStyle(
                                color: theme.colorScheme.onInverseSurface,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                      ),
                    ),
                    barGroups: [
                      for (final (i, t) in trend.indexed)
                        BarChartGroupData(
                          x: i,
                          barsSpace: 3,
                          barRods: [
                            _rod(t.income, _incomeColor),
                            _rod(t.expense, _expenseColor),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static BarChartRodData _rod(double value, Color color) => BarChartRodData(
    toY: value,
    color: color,
    width: 10,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
