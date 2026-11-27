import 'package:flutter/material.dart';
import '../../../wallets/presentation/widgets/wallet_widgets.dart';
import '../../../wallets/presentation/providers/wallet_providers.dart';
import '../../../wallets/presentation/pages/wallet_pages.dart';
import '../../../wallets/domain/wallet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
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
class HistoryTab extends ConsumerStatefulWidget {
  const HistoryTab({super.key});

  @override
  ConsumerState<HistoryTab> createState() => _HistoryTabState();
}

/// Filter cepat di Riwayat.
enum _Filter {
  all('Semua'),
  income('Pemasukan'),
  expense('Pengeluaran'),
  transfer('Transfer');

  const _Filter(this.label);
  final String label;
}

class _HistoryTabState extends ConsumerState<HistoryTab> {
  _Filter _filter = _Filter.all;

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
  Widget build(BuildContext context) {
    final month = ref.watch(selectedMonthProvider);
    final monthNotifier = ref.read(selectedMonthProvider.notifier);
    final allTransactions = ref.watch(monthTransactionsProvider);
    final allTransfers = ref.watch(monthTransfersProvider);
    final transactions = switch (_filter) {
      _Filter.all => allTransactions,
      _Filter.income => allTransactions.where((t) => t.isIncome).toList(),
      _Filter.expense => allTransactions.where((t) => !t.isIncome).toList(),
      _Filter.transfer => const <Transaction>[],
    };
    final transfers = switch (_filter) {
      _Filter.all || _Filter.transfer => allTransfers,
      _ => const <Transfer>[],
    };
    final p = context.palette;
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
        if (allTransactions.isEmpty && allTransfers.isEmpty)
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
          Semantics(
            label:
                '${allTransactions.length} transaksi · '
                'Masuk ${Fmt.rupiah(summary.totalIncome)} · '
                'Keluar ${Fmt.rupiah(summary.totalExpense)}',
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      _Stat(
                        label: 'Transaksi',
                        value: '${allTransactions.length}',
                        color: p.ink,
                      ),
                      VerticalDivider(color: p.border, width: 1),
                      _Stat(
                        label: 'Masuk',
                        value: Fmt.rupiah(summary.totalIncome),
                        color: p.income,
                      ),
                      VerticalDivider(color: p.border, width: 1),
                      _Stat(
                        label: 'Keluar',
                        value: Fmt.rupiah(summary.totalExpense),
                        color: p.expense,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in _Filter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.label),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          if (transactions.isEmpty && transfers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text(
                'Tidak ada ${_filter.label.toLowerCase()} di bulan ini.',
                textAlign: TextAlign.center,
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
                  for (final (i, item) in items.indexed) ...[
                    if (i > 0) const Divider(indent: 72, endIndent: 16),
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
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
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

/// Satu angka di strip ringkasan Riwayat.
class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: .6,
              color: context.palette.inkMuted,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
