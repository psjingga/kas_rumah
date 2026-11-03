import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
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
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.secondaryContainer.withValues(alpha: .5),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.event_repeat, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Rutin bulan ini',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${items.length} belum dicatat',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          for (final o in items)
            ListTile(
              onTap: () => onEdit(o),
              leading: Icon(
                o.recurring.category.icon,
                color: o.recurring.category.color,
              ),
              title: Text(
                o.recurring.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  Fmt.date(o.date),
                  Fmt.rupiah(o.recurring.amount),
                  // Cicilan: "ke-3/12".
                  if (o.recurring.totalOccurrences case final total?)
                    'ke-${o.number}/$total',
                ].join(' · '),
              ),
              trailing: IconButton(
                tooltip: 'Catat ${o.recurring.title}',
                icon: Icon(Icons.check_circle_outline, color: scheme.primary),
                onPressed: () => onRecord(o),
              ),
            ),
          if (items.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: FilledButton.tonalIcon(
                onPressed: onRecordAll,
                icon: const Icon(Icons.done_all),
                label: Text('Catat semua (${items.length})'),
              ),
            ),
        ],
      ),
    );
  }
}
