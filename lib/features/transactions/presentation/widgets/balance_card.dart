import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/entities/finance_summary.dart';

/// Kartu ringkasan: sisa saldo bulan ini besar di atas, sisa bulan lalu
/// sebagai keterangan (tidak ikut dijumlahkan), lalu pemasukan &
/// pengeluaran.
class BalanceCard extends StatelessWidget {
  const BalanceCard({super.key, required this.summary});

  final FinanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final negatif = summary.balance < 0;
    final muted = TextStyle(
      color: scheme.onPrimary.withValues(alpha: .8),
      fontSize: 12.5,
    );

    return Card(
      color: scheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sisa Saldo',
              style: TextStyle(color: scheme.onPrimary.withValues(alpha: .8)),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                Fmt.rupiah(summary.balance),
                style: TextStyle(
                  color: negatif ? const Color(0xFFFFCDD2) : scheme.onPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Hanya informasi; tidak ditambahkan ke sisa saldo bulan ini.
            Text(
              'Sisa bulan lalu ${Fmt.rupiah(summary.previousMonthBalance)}',
              style: muted,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Total(
                    label: 'Pemasukan',
                    value: summary.totalIncome,
                    icon: Icons.south_west,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Total(
                    label: 'Pengeluaran',
                    value: summary.totalExpense,
                    icon: Icons.north_east,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Total extends StatelessWidget {
  const _Total({required this.label, required this.value, required this.icon});

  final String label;
  final double value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
