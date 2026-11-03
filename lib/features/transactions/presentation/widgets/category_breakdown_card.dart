import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/entities/finance_summary.dart';

/// Rincian pengeluaran per kategori: ikon, nominal, dan bar porsi.
/// Urut dari pengeluaran terbesar; tidak tampil bila belum ada pengeluaran.
class CategoryBreakdownCard extends StatelessWidget {
  const CategoryBreakdownCard({super.key, required this.summary});

  final FinanceSummary summary;

  @override
  Widget build(BuildContext context) {
    final entries = summary.expenseByCategory.entries;
    if (entries.isEmpty) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pengeluaran per Kategori', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            for (final MapEntry(key: category, value: amount) in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: category.color.withValues(alpha: .15),
                      child: Icon(
                        category.icon,
                        color: category.color,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  category.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                Fmt.rupiah(amount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: summary.shareOf(category),
                                    minHeight: 6,
                                    color: category.color,
                                    backgroundColor: category.color.withValues(
                                      alpha: .12,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 48,
                                child: Text(
                                  '${(summary.shareOf(category) * 100).toStringAsFixed(1)}%',
                                  textAlign: TextAlign.right,
                                  style: textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ],
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
