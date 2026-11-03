import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../providers/transaction_providers.dart';
import '../widgets/month_selector.dart';
import '../widgets/transaction_actions.dart';
import '../widgets/transaction_tile.dart';

/// Tab Riwayat: semua transaksi bulan terpilih. Ketuk untuk mengubah,
/// geser ke kiri untuk menghapus.
class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final monthNotifier = ref.read(selectedMonthProvider.notifier);
    final transactions = ref.watch(monthTransactionsProvider);
    final summary = ref.watch(financeSummaryProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      children: [
        MonthSelector(
          month: month,
          isThisMonth: monthNotifier.isThisMonth,
          onPrevious: monthNotifier.previous,
          onNext: monthNotifier.next,
          onThisMonth: monthNotifier.goToThisMonth,
        ),
        if (transactions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(
                'Belum ada transaksi di bulan ini.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              '${transactions.length} transaksi · '
              'Masuk ${Fmt.rupiah(summary.totalIncome)} · '
              'Keluar ${Fmt.rupiah(summary.totalExpense)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final t in transactions)
                  TransactionTile(
                    key: ValueKey(t.id),
                    transaction: t,
                    onTap: () =>
                        openTransactionForm(context, month: month, initial: t),
                    onDelete: () => deleteTransactionWithUndo(context, ref, t),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
