import 'package:flutter/material.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/warm_widgets.dart';
import '../../domain/entities/recurring_transaction.dart';

/// Daftar transaksi rutin yang belum dicatat di bulan terpilih.
///
/// Tombol ✓ mencatat dengan nominal default; ketuk baris untuk mengubah
/// nominal khusus bulan ini sebelum dicatat.
class RecurringDueCard extends StatelessWidget {
  const RecurringDueCard({
    super.key,
    required this.items,
    required this.month,
    required this.onRecord,
    required this.onEdit,
    required this.onRecordAll,
  });

  final List<RecurringOccurrence> items;
  final DateTime month;
  final ValueChanged<RecurringOccurrence> onRecord;
  final ValueChanged<RecurringOccurrence> onEdit;
  final VoidCallback onRecordAll;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
            child: Row(
              children: [
                Icon(Icons.event_repeat_rounded, size: 20, color: p.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Rutin bulan ini', style: textTheme.titleSmall),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: p.warningSoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${items.length} belum dicatat',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? p.warning
                          : const Color(0xFF8A6400),
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final (i, o) in items.indexed) ...[
            if (i > 0) const Divider(indent: 18, endIndent: 18),
            InkWell(
              onTap: () => onEdit(o),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: o.recurring.isIncome ? p.income : p.warning,
                      width: 4,
                    ),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                child: Row(
                  children: [
                    IconTile(
                      icon: o.recurring.category.icon,
                      color: o.recurring.category.color,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            o.recurring.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleSmall,
                          ),
                          Text(
                            [
                              Fmt.date(o.date),
                              Fmt.rupiah(o.recurring.amount),
                              // Cicilan: "ke-3/12".
                              if (o.recurring.totalOccurrences
                                  case final total?)
                                'ke-${o.number}/$total',
                            ].join(' · '),
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Catat ${o.recurring.title}',
                      icon: Icon(
                        Icons.check_circle_outline_rounded,
                        color: p.primary,
                        size: 28,
                      ),
                      onPressed: () => onRecord(o),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (items.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: FilledButton.tonalIcon(
                onPressed: onRecordAll,
                icon: const Icon(Icons.done_all_rounded),
                label: Text('Catat semua (${items.length})'),
              ),
            ),
        ],
      ),
    );
  }
}
