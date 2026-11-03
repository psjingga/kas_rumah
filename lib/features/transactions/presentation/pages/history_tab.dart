import 'package:flutter/material.dart';
import '../../../wallets/presentation/widgets/wallet_widgets.dart';
import '../../../wallets/presentation/providers/wallet_providers.dart';
import '../../../wallets/presentation/pages/wallet_pages.dart';
import '../../../wallets/domain/wallet.dart';
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

  /// Kelompokkan transaksi & transfer per tanggal (terbaru dulu).
  /// Item berupa [Transaction] atau [Transfer].
  static List<(DateTime, List<Object>)> _byDay(
    List<Transaction> transactions,
    List<Transfer> transfers,
  ) {
    final items = <(DateTime, Object)>[
      for (final t in transactions) (t.date, t),
      for (final t in transfers) (t.date, t),
    ]..sort((a, b) => b.$1.compareTo(a.$1));
    final groups = <(DateTime, List<Object>)>[];
    for (final (date, item) in items) {
      final day = DateUtils.dateOnly(date);
      if (groups.isEmpty || groups.last.$1 != day) groups.add((day, []));
      groups.last.$2.add(item);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final monthNotifier = ref.read(selectedMonthProvider.notifier);
    final transactions = ref.watch(monthTransactionsProvider);
    final transfers = ref.watch(monthTransfersProvider);
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
        if (transactions.isEmpty && transfers.isEmpty)
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
          for (final (day, items) in _byDay(transactions, transfers)) ...[
            _DayHeader(
              day: day,
              now: now,
              items: items.whereType<Transaction>().toList(),
            ),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final item in items)
                    switch (item) {
                      final Transaction t => TransactionTile(
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
                      final Transfer t => TransferTile(
                        key: ValueKey('tr-${t.id}'),
                        transfer: t,
                        onDelete: () => deleteTransferWithUndo(context, ref, t),
                      ),
                      _ => const SizedBox.shrink(),
                    },
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
          if (items.isNotEmpty)
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
