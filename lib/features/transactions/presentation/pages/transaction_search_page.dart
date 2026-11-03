import 'package:flutter/material.dart';
import '../../../wallets/presentation/providers/wallet_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/month.dart';
import '../../domain/entities/finance_summary.dart';
import '../../domain/entities/transaction.dart';
import '../../domain/entities/transaction_filter.dart';
import '../providers/category_providers.dart';
import '../providers/transaction_providers.dart';
import '../widgets/transaction_actions.dart';
import '../widgets/transaction_tile.dart';

/// Pencarian & filter riwayat di **semua bulan**: kata kunci, jenis, dan
/// kategori. Hasil dikelompokkan per bulan.
class TransactionSearchPage extends ConsumerStatefulWidget {
  const TransactionSearchPage({super.key});

  @override
  ConsumerState<TransactionSearchPage> createState() =>
      _TransactionSearchPageState();
}

class _TransactionSearchPageState extends ConsumerState<TransactionSearchPage> {
  var _filter = const TransactionFilter();

  @override
  Widget build(BuildContext context) {
    final results = _filter.apply(ref.watch(transactionsProvider));
    final summary = FinanceSummary.from(results);
    final categories = _filter.type == null
        ? ref.watch(allCategoriesProvider)
        : ref.watch(categoriesOfTypeProvider(_filter.type!));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Cari judul, kategori, atau nominal…',
            border: InputBorder.none,
          ),
          onChanged: (q) => setState(() => _filter = _filter.withQuery(q)),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Filter jenis.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Wrap(
              spacing: 8,
              children: [
                for (final (label, type) in [
                  ('Semua', null),
                  ('Pemasukan', TransactionType.income),
                  ('Pengeluaran', TransactionType.expense),
                ])
                  ChoiceChip(
                    label: Text(label),
                    selected: _filter.type == type,
                    onSelected: (_) =>
                        setState(() => _filter = _filter.withType(type)),
                  ),
              ],
            ),
          ),
          // Filter kategori (geser horizontal).
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final c in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Icon(c.icon, size: 16, color: c.color),
                      label: Text(c.label),
                      selected: _filter.category == c,
                      onSelected: (on) => setState(
                        () => _filter = _filter.withCategory(on ? c : null),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Filter dompet (hanya bila dompet lebih dari satu).
          if (ref.watch(walletsProvider) case final wallets
              when wallets.length > 1)
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                children: [
                  for (final w in wallets)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        avatar: Icon(w.type.icon, size: 16, color: w.color),
                        label: Text(w.name),
                        selected: _filter.walletId == w.id,
                        onSelected: (on) => setState(
                          () => _filter = _filter.withWallet(on ? w.id : null),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              results.isEmpty
                  ? 'Tidak ada transaksi yang cocok.'
                  : '${results.length} transaksi · '
                        'Masuk ${Fmt.rupiah(summary.totalIncome)} · '
                        'Keluar ${Fmt.rupiah(summary.totalExpense)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          ..._grouped(results),
        ],
      ),
    );
  }

  /// Hasil dikelompokkan per bulan dengan judul bulan.
  Iterable<Widget> _grouped(List<Transaction> results) sync* {
    DateTime? current;
    for (final t in results) {
      final month = t.date.firstOfMonth;
      if (month != current) {
        current = month;
        yield Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            Fmt.month(month),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        );
      }
      yield TransactionTile(
        key: ValueKey(t.id),
        transaction: t,
        onTap: () => openTransactionForm(context, month: month, initial: t),
        onDelete: () => deleteTransactionWithUndo(context, ref, t),
      );
    }
  }
}
