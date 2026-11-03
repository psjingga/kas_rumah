import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/entities/transaction.dart';

/// Satu baris transaksi. Ketuk untuk mengubah, geser ke kiri untuk menghapus.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.onTap,
    required this.onDelete,
  });

  final Transaction transaction;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = transaction;
    final scheme = Theme.of(context).colorScheme;
    final amountColor = t.isIncome ? const Color(0xFF2E7D32) : scheme.error;

    return Dismissible(
      key: ValueKey(t.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: scheme.errorContainer,
        child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: t.category.color.withValues(alpha: .15),
          child: Icon(t.category.icon, color: t.category.color, size: 20),
        ),
        title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Row(
          children: [
            // Penanda transaksi hasil catatan transaksi rutin.
            if (t.isRecurring) ...[
              Icon(Icons.event_repeat, size: 14, color: scheme.outline),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                '${t.category.label} · ${Fmt.date(t.date)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: Text(
          '${t.isIncome ? '+' : '−'} ${Fmt.rupiah(t.amount)}',
          style: TextStyle(color: amountColor, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
