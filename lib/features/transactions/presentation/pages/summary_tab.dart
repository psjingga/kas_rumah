import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../budgets/presentation/widgets/budget_overview_card.dart';
import '../../../goals/presentation/widgets/goals_overview_card.dart';
import '../../domain/entities/recurring_transaction.dart';
import '../providers/recurring_providers.dart';
import '../providers/transaction_providers.dart';
import '../widgets/balance_card.dart';
import '../widgets/category_breakdown_card.dart';
import '../widgets/income_expense_chart.dart';
import '../widgets/month_selector.dart';
import '../widgets/monthly_trend_chart.dart';
import '../widgets/recurring_due_card.dart';
import '../widgets/transaction_actions.dart';

/// Tab Ringkasan per bulan: sisa saldo, transaksi rutin yang belum dicatat,
/// grafik pemasukan vs pengeluaran, rincian kategori, dan tren 6 bulan.
class SummaryTab extends ConsumerWidget {
  const SummaryTab({super.key});

  /// Catat satu transaksi rutin dengan nominal default.
  Future<void> _record(
    BuildContext context,
    WidgetRef ref,
    RecurringTransaction recurring,
  ) async {
    final notifier = ref.read(transactionsProvider.notifier);
    final created = await notifier.recordRecurring(
      recurring,
      ref.read(selectedMonthProvider),
    );
    unawaited(HapticFeedback.lightImpact());
    if (!context.mounted) return;
    showAppSnack(
      context,
      '"${recurring.title}" dicatat ${Fmt.rupiah(created.amount)}.',
      SnackBarAction(
        label: 'Urungkan',
        onPressed: () => notifier.remove(created.id),
      ),
    );
  }

  Future<void> _recordAll(
    BuildContext context,
    WidgetRef ref,
    List<RecurringTransaction> items,
  ) async {
    await ref
        .read(transactionsProvider.notifier)
        .recordAllRecurring(items, ref.read(selectedMonthProvider));
    if (context.mounted) {
      showAppSnack(context, '${items.length} transaksi rutin dicatat.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final monthNotifier = ref.read(selectedMonthProvider.notifier);
    final summary = ref.watch(financeSummaryProvider);
    final previous = ref.watch(previousMonthSummaryProvider);
    final pending = ref.watch(pendingRecurringProvider);

    return MonthSwipe(
      onPrevious: monthNotifier.previous,
      onNext: monthNotifier.next,
      child: ListView(
        // Ruang bawah agar item terakhir tidak tertutup FAB.
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          MonthSelector(
            month: month,
            isThisMonth: monthNotifier.isThisMonth,
            onPrevious: monthNotifier.previous,
            onNext: monthNotifier.next,
            onThisMonth: monthNotifier.goToThisMonth,
          ),
          const SizedBox(height: 4),
          BalanceCard(summary: summary, previous: previous),
          const SizedBox(height: 12),
          // Status anggaran & tabungan; ketuk untuk membuka tabnya.
          const IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: BudgetOverviewCard()),
                SizedBox(width: 12),
                Expanded(child: GoalsOverviewCard()),
              ],
            ),
          ),
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 12),
            RecurringDueCard(
              items: pending,
              month: month,
              onRecord: (r) => _record(context, ref, r),
              onEdit: (r) =>
                  openTransactionForm(context, month: month, recurring: r),
              onRecordAll: () => _recordAll(context, ref, pending),
            ),
          ],
          const SizedBox(height: 12),
          IncomeExpenseChart(summary: summary),
          if (summary.expenseByCategory.isNotEmpty) ...[
            const SizedBox(height: 12),
            CategoryBreakdownCard(summary: summary, previous: previous),
          ],
          const SizedBox(height: 12),
          MonthlyTrendChart(
            trend: ref.watch(monthlyTrendProvider),
            selectedMonth: month,
            onSelectMonth: monthNotifier.select,
          ),
        ],
      ),
    );
  }
}
