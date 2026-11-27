import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/warm_widgets.dart';
import '../../domain/entities/finance_summary.dart';

/// Kartu ringkasan: sisa saldo bulan ini besar di atas, sisa bulan lalu
/// sebagai keterangan (tidak ikut dijumlahkan), lalu pemasukan &
/// pengeluaran.
class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.summary,
    this.previous,
    this.scheduledNet,
    this.header,
  });

  final FinanceSummary summary;

  /// Ringkasan bulan lalu, untuk perbandingan pemasukan & pengeluaran.
  final FinanceSummary? previous;

  /// Total bertanda transaksi bulan ini yang tanggalnya setelah hari ini
  /// (sudah ikut dihitung di sisa saldo). `null`/0 = tidak ada.
  final double? scheduledNet;

  /// Isi di bagian atas hero (mis. pemilih bulan).
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const foreground = Colors.white;
    final negatif = summary.balance < 0;
    final muted = TextStyle(
      color: foreground.withValues(alpha: .85),
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
    );

    // Latar gradasi madu memenuhi lebar layar; kartu Pemasukan &
    // Pengeluaran menumpang di tepi bawahnya.
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          bottom: 44,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [p.heroStart, p.heroEnd],
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppRadius.hero + 4),
              ),
            ),
          ),
        ),
        Column(
          children: [
            ?header,
            const SizedBox(height: 4),
            Text('Sisa Saldo', style: muted.copyWith(fontSize: 13)),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                // Angka bergulir halus saat saldo berubah.
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: summary.balance),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => Text(
                    Fmt.rupiah(value.roundToDouble()),
                    style: TextStyle(
                      color: negatif ? const Color(0xFFFFE1DE) : foreground,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Hanya informasi; tidak ditambahkan ke sisa saldo bulan ini.
            Text(
              'Sisa bulan lalu ${Fmt.rupiah(summary.previousMonthBalance)}',
              style: muted,
            ),
            // Sisa saldo menghitung seluruh bulan, termasuk yang terjadwal.
            if (scheduledNet case final s? when s.abs() >= 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Termasuk ${Fmt.signed(s)} terjadwal setelah hari ini',
                  style: muted,
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 18),
            // IntrinsicHeight: kedua kartu selalu sama tinggi.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _Total(
                        label: 'Pemasukan',
                        value: summary.totalIncome,
                        icon: Icons.trending_up_rounded,
                        color: p.income,
                        sign: '+',
                        change: previous == null
                            ? null
                            : Fmt.change(
                                    previous!.totalIncome,
                                    summary.totalIncome,
                                  ) ??
                                  '—',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Total(
                        label: 'Pengeluaran',
                        value: summary.totalExpense,
                        icon: Icons.trending_down_rounded,
                        color: p.expense,
                        sign: '−',
                        change: previous == null
                            ? null
                            : Fmt.change(
                                    previous!.totalExpense,
                                    summary.totalExpense,
                                  ) ??
                                  '—',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.sign,
    this.change,
  });

  final String label;
  final double value;
  final IconData icon;
  final Color color;
  final String sign;

  /// Perubahan dari bulan lalu, mis. "▲12%".
  final String? change;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: p.border.withValues(alpha: .6)),
        boxShadow: p.cardShadow,
      ),
      child: Column(
        children: [
          IconTile(icon: icon, color: color, size: 36),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: .6,
              color: p.inkMuted,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$sign ${Fmt.rupiah(value)}',
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (change case final c?)
            Text(
              '$c vs bln lalu',
              style: TextStyle(color: p.inkMuted, fontSize: 11),
            ),
        ],
      ),
    );
  }
}
