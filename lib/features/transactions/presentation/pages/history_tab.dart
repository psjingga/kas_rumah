import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/money_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/entities/transaction.dart';
import '../providers/transaction_providers.dart';
import '../widgets/month_selector.dart';
import '../widgets/transaction_actions.dart';
import '../widgets/transaction_tile.dart';

/// Tab Riwayat: transaksi bulan terpilih dikelompokkan per hari, masing-masing
/// dengan total bersih harian. Ketuk untuk mengubah, geser kiri untuk hapus.
class HistoryTab extends ConsumerWidget {
  const HistoryTab({super.key});

  /// Kelompokkan transaksi (sudah urut terbaru) per tanggal.
  static List<(DateTime, List<Transaction>)> _byDay(List<Transaction> list) {
    final groups = <(DateTime, List<Transaction>)>[];
    for (final t in list) {
      final day = DateUtils.dateOnly(t.date);
      if (groups.isEmpty || groups.last.$1 != day) groups.add((day, []));
      groups.last.$2.add(t);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final monthNotifier = ref.read(selectedMonthProvider.notifier);
    final transactions = ref.watch(monthTransactionsProvider);
    final summary = ref.watch(financeSummaryProvider);
    final now = ref.read(clockProvider)();

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
          EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'Belum ada transaksi di bulan ini.',
            message:
                'Catat pemasukan dan pengeluaran agar sisa saldo '
                'dan grafiknya muncul.',
            actionLabel: 'Tambah transaksi',
            onAction: () => openTransactionForm(context, month: month),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
            child: Text(
              '${transactions.length} transaksi · '
              'Masuk ${Fmt.rupiah(summary.totalIncome)} · '
              'Keluar ${Fmt.rupiah(summary.totalExpense)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          for (final (day, items) in _byDay(transactions)) ...[
            _DayHeader(day: day, now: now, items: items),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final t in items)
                    TransactionTile(
                      key: ValueKey(t.id),
                      transaction: t,
                      showDate: false,
                      onTap: () => openTransactionForm(
                        context,
                        month: month,
                        initial: t,
                      ),
                      onDelete: () =>
                          deleteTransactionWithUndo(context, ref, t),
                    ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// "Senin, 2 Nov ........ −Rp 120.000"
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.now, required this.items});

  final DateTime day;
  final DateTime now;
  final List<Transaction> items;

  @override
  Widget build(BuildContext context) {
    final net = items.fold(0.0, (s, t) => s + t.signedAmount);
    final style = Theme.of(context).textTheme.titleSmall;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              Fmt.dayHeader(day, now),
              style: style?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            Fmt.signed(net),
            style: style?.copyWith(
              fontWeight: FontWeight.w700,
              color: net >= 0 ? context.incomeColor : context.expenseColor,
            ),
          ),
        ],
      ),
    );
  }
}
