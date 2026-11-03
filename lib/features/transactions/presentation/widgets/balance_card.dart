import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
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
  });

  final FinanceSummary summary;

  /// Ringkasan bulan lalu, untuk perbandingan pemasukan & pengeluaran.
  final FinanceSummary? previous;

  /// Total bertanda transaksi bulan ini yang tanggalnya setelah hari ini
  /// (sudah ikut dihitung di sisa saldo). `null`/0 = tidak ada.
  final double? scheduledNet;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = balanceCardColors(context);
    final negatif = summary.balance < 0;
    final muted = TextStyle(
      color: foreground.withValues(alpha: .8),
      fontSize: 12.5,
    );

    return Card(
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sisa Saldo',
              style: TextStyle(color: foreground.withValues(alpha: .8)),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              // Angka bergulir halus saat saldo berubah.
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: summary.balance),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => Text(
                  Fmt.rupiah(value.roundToDouble()),
                  style: TextStyle(
                    color: negatif ? const Color(0xFFFFCDD2) : foreground,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.5,
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
              Text(
                'Termasuk ${Fmt.signed(s)} terjadwal setelah hari ini',
                style: muted,
              ),
            const SizedBox(height: 16),
            // IntrinsicHeight: kedua kotak selalu sama tinggi.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _Total(
                      label: 'Pemasukan',
                      value: summary.totalIncome,
                      icon: Icons.south_west,
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
                      icon: Icons.north_east,
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
          ],
        ),
      ),
    );
  }
}

/// Warna kartu saldo: teal penuh di mode terang, teal tua di mode gelap
/// (teal terang terlalu menyilaukan di layar gelap).
(Color, Color) balanceCardColors(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  return scheme.brightness == Brightness.dark
      ? (scheme.primaryContainer, scheme.onPrimaryContainer)
      : (scheme.primary, scheme.onPrimary);
}

class _Total extends StatelessWidget {
  const _Total({
    required this.label,
    required this.value,
    required this.icon,
    this.change,
  });

  final String label;
  final double value;
  final IconData icon;

  /// Perubahan dari bulan lalu, mis. "▲12%".
  final String? change;

  @override
  Widget build(BuildContext context) {
    final onPrimary = balanceCardColors(context).$2;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: onPrimary.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: onPrimary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: onPrimary.withValues(alpha: .8),
                    fontSize: 12,
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Fmt.rupiah(value),
                    style: TextStyle(
                      color: onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (change case final c?)
                  Text(
                    '$c vs bln lalu',
                    style: TextStyle(
                      color: onPrimary.withValues(alpha: .75),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
