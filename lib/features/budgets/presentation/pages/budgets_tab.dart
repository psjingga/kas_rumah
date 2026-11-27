import 'package:flutter/material.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/theme/money_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/warm_widgets.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/presentation/providers/category_providers.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../../transactions/presentation/widgets/month_selector.dart';
import '../../domain/budget.dart';
import '../providers/budget_providers.dart';

/// Warna tingkat anggaran: hijau aman, oranye hampir habis, merah lewat.
Color budgetLevelColor(BuildContext context, BudgetLevel level) =>
    switch (level) {
      BudgetLevel.safe => context.incomeColor,
      BudgetLevel.warning => context.warningColor,
      BudgetLevel.over => context.expenseColor,
    };

/// Tab Anggaran: batas pengeluaran per kategori dan pemakaiannya di bulan
/// terpilih.
class BudgetsTab extends ConsumerWidget {
  const BudgetsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedMonthProvider);
    final monthNotifier = ref.read(selectedMonthProvider.notifier);
    final statuses = ref.watch(budgetStatusProvider);
    final totalLimit = statuses.fold(0.0, (s, b) => s + b.limit);
    final totalSpent = statuses.fold(0.0, (s, b) => s + b.spent);

    return MonthSwipe(
      onPrevious: monthNotifier.previous,
      onNext: monthNotifier.next,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          MonthSelector(
            month: month,
            isThisMonth: monthNotifier.isThisMonth,
            onPrevious: monthNotifier.previous,
            onNext: monthNotifier.next,
            onThisMonth: monthNotifier.goToThisMonth,
          ),
          if (statuses.isEmpty)
            EmptyState(
              icon: Icons.pie_chart_outline,
              title: 'Belum ada anggaran',
              message:
                  'Batasi pengeluaran per kategori setiap bulan, mis. '
                  'Makanan Rp 3.000.000. Kamu akan diberi tahu saat '
                  'hampir habis.',
              actionLabel: 'Atur anggaran',
              onAction: () => pickCategoryForBudget(context, ref),
            )
          else ...[
            _TotalCard(limit: totalLimit, spent: totalSpent),
            const SizedBox(height: 20),
            SectionLabel('Per kategori · ${statuses.length}'),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (i, s) in statuses.indexed) ...[
                    if (i > 0) const Divider(indent: 68, endIndent: 16),
                    _BudgetTile(
                      status: s,
                      onTap: () => showBudgetLimitDialog(
                        context,
                        ref,
                        s.category,
                        current: s.limit,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.limit, required this.spent});

  final double limit;
  final double spent;

  @override
  Widget build(BuildContext context) {
    final ratio = limit == 0 ? 0.0 : spent / limit;
    final color = budgetLevelColor(context, BudgetLevel.of(ratio));
    final textTheme = Theme.of(context).textTheme;
    final p = context.palette;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            // Cincin terpakai vs batas.
            SizedBox.square(
              dimension: 104,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: ratio.clamp(0, 1).toDouble()),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => CircularProgressIndicator(
                      value: v,
                      strokeWidth: 11,
                      strokeCap: StrokeCap.round,
                      color: color,
                      backgroundColor: p.surfaceMuted,
                    ),
                  ),
                  Center(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${(ratio * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          TextSpan(
                            text: '\nterpakai',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: p.inkMuted,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total anggaran bulan ini', style: textTheme.bodySmall),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      Fmt.rupiah(spent),
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  Text('dari ${Fmt.rupiah(limit)}', style: textTheme.bodySmall),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      limit >= spent
                          ? 'Sisa ${Fmt.rupiah(limit - spent)}'
                          : 'Lebih ${Fmt.rupiah(spent - limit)}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({required this.status, required this.onTap});

  final BudgetStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final color = budgetLevelColor(context, s.level);
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            IconTile(icon: s.category.icon, color: s.category.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.category.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      if (s.level == BudgetLevel.over) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: p.expenseSoft,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'Lewat batas',
                            style: TextStyle(
                              color: p.expense,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        '${(s.ratio * 100).round()}%',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SoftProgress(value: s.ratio, color: color),
                  const SizedBox(height: 6),
                  Text(
                    '${Fmt.rupiah(s.spent)} dari ${Fmt.rupiah(s.limit)} · '
                    '${s.remaining >= 0 ? 'sisa ${Fmt.rupiah(s.remaining)}' : 'lebih ${Fmt.rupiah(-s.remaining)}'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pilih kategori pengeluaran yang belum punya anggaran, lalu isi batasnya.
Future<void> pickCategoryForBudget(BuildContext context, WidgetRef ref) async {
  final limits = ref.read(budgetLimitsProvider);
  final options = [
    for (final c in ref.read(categoriesOfTypeProvider(TransactionType.expense)))
      if (!limits.containsKey(c.id)) c,
  ];
  final picked = await showModalBottomSheet<TransactionCategory>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * .7,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Pilih kategori pengeluaran',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            if (options.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Semua kategori sudah punya anggaran.'),
              ),
            for (final c in options)
              ListTile(
                leading: IconTile(icon: c.icon, color: c.color, size: 36),
                title: Text(c.label),
                onTap: () => Navigator.pop(ctx, c),
              ),
          ],
        ),
      ),
    ),
  );
  if (picked != null && context.mounted) {
    await showBudgetLimitDialog(context, ref, picked);
  }
}

/// Dialog isi/ubah/hapus batas anggaran [category].
Future<void> showBudgetLimitDialog(
  BuildContext context,
  WidgetRef ref,
  TransactionCategory category, {
  double? current,
}) async {
  final controller = TextEditingController(
    text: current == null ? null : Fmt.thousands(current),
  );
  final formKey = GlobalKey<FormState>();
  // null = batal, 0 = hapus, >0 = batas baru.
  final result = await showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Anggaran ${category.label}'),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: const [ThousandsInputFormatter()],
          decoration: const InputDecoration(
            labelText: 'Batas per bulan',
            prefixText: 'Rp ',
          ),
          validator: (v) => (Fmt.parseAmount(v ?? '') ?? 0) > 0
              ? null
              : 'Isi nominal lebih dari 0',
        ),
      ),
      actions: [
        if (current != null)
          TextButton(
            onPressed: () => Navigator.pop(ctx, 0.0),
            child: const Text('Hapus'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(ctx, Fmt.parseAmount(controller.text));
            }
          },
          child: const Text('Simpan'),
        ),
      ],
    ),
  );
  if (result == null) return;
  await ref
      .read(budgetLimitsProvider.notifier)
      .setLimit(category.id, result == 0 ? null : result);
}
