import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../transactions/presentation/providers/category_providers.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../../transactions/presentation/widgets/month_selector.dart';
import '../../domain/budget.dart';
import '../providers/budget_providers.dart';

const _safeColor = Color(0xFF2E7D32);
const _warningColor = Color(0xFFEF6C00);
const _overColor = Color(0xFFE53935);

Color budgetLevelColor(BudgetLevel level) => switch (level) {
  BudgetLevel.safe => _safeColor,
  BudgetLevel.warning => _warningColor,
  BudgetLevel.over => _overColor,
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
        if (statuses.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48, horizontal: 16),
            child: Text(
              'Belum ada anggaran.\nKetuk "Anggaran" untuk membatasi '
              'pengeluaran per kategori setiap bulan, mis. Makanan '
              'Rp 3.000.000.',
              textAlign: TextAlign.center,
            ),
          )
        else ...[
          _TotalCard(limit: totalLimit, spent: totalSpent),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final s in statuses)
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
            ),
          ),
        ],
      ],
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
    final color = budgetLevelColor(BudgetLevel.of(ratio));
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total anggaran bulan ini', style: textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              '${Fmt.rupiah(spent)} / ${Fmt.rupiah(limit)}',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio.clamp(0, 1),
                minHeight: 10,
                color: color,
                backgroundColor: color.withValues(alpha: .15),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              limit >= spent
                  ? 'Sisa ${Fmt.rupiah(limit - spent)}'
                  : 'Lebih ${Fmt.rupiah(spent - limit)}',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
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
    final color = budgetLevelColor(s.level);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: s.category.color.withValues(alpha: .15),
              child: Icon(s.category.icon, color: s.category.color, size: 18),
            ),
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
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        '${(s.ratio * 100).round()}%',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: s.ratio.clamp(0, 1),
                      minHeight: 6,
                      color: color,
                      backgroundColor: color.withValues(alpha: .15),
                    ),
                  ),
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
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Pilih kategori pengeluaran'),
            ),
            if (options.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Semua kategori sudah punya anggaran.'),
              ),
            for (final c in options)
              ListTile(
                leading: Icon(c.icon, color: c.color),
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
