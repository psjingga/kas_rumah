import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/home_tab.dart';
import '../../../../core/theme/money_colors.dart';
import '../../../../core/widgets/insight_card.dart';
import '../../domain/budget.dart';
import '../pages/budgets_tab.dart';
import '../providers/budget_providers.dart';

/// Ringkasan anggaran bulan terpilih untuk tab Ringkasan.
class BudgetOverviewCard extends ConsumerWidget {
  const BudgetOverviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref.watch(budgetStatusProvider);
    void open() => ref.read(homeTabProvider.notifier).select(HomeTab.budgets);

    if (statuses.isEmpty) {
      return InsightCard(
        icon: Icons.pie_chart_outline,
        title: 'Anggaran',
        value: 'Belum diatur',
        caption: 'Batasi pengeluaran',
        onTap: open,
      );
    }

    final over = statuses.where((s) => s.level == BudgetLevel.over).length;
    final warning = statuses
        .where((s) => s.level == BudgetLevel.warning)
        .length;
    final limit = statuses.fold(0.0, (s, b) => s + b.limit);
    final spent = statuses.fold(0.0, (s, b) => s + b.spent);
    final ratio = limit == 0 ? 0.0 : spent / limit;

    return InsightCard(
      icon: Icons.pie_chart_outline,
      title: 'Anggaran',
      value: switch ((over, warning)) {
        (0, 0) => 'Semua aman',
        (0, final w) => '$w hampir habis',
        (final o, 0) => '$o terlampaui',
        (final o, final w) => '$o lewat · $w hampir',
      },
      caption: '${(ratio * 100).round()}% terpakai',
      progress: ratio,
      color: over > 0
          ? context.expenseColor
          : budgetLevelColor(context, BudgetLevel.of(ratio)),
      onTap: open,
    );
  }
}
