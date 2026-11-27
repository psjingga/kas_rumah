import 'package:flutter/material.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/theme/money_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/warm_widgets.dart';
import '../../../transactions/domain/entities/transaction_category.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../domain/savings_goal.dart';
import '../providers/goal_providers.dart';
import 'goal_pages.dart';

/// Tab Tabungan: daftar target tabungan dan progresnya.
class GoalsTab extends ConsumerWidget {
  const GoalsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    final now = ref.read(clockProvider)();
    final totalSaved = goals.fold(0.0, (s, g) => s + g.saved);

    if (goals.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: EmptyState(
            icon: Icons.savings_outlined,
            title: 'Belum ada target tabungan',
            message:
                'Tentukan tujuan seperti Dana darurat Rp 10.000.000, '
                'lalu setor sedikit demi sedikit.',
            actionLabel: 'Buat target',
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const GoalFormPage()),
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        _TotalCard(goals: goals, totalSaved: totalSaved),
        const SizedBox(height: 20),
        SectionLabel('Target · ${goals.length}'),
        for (final g in goals)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GoalCard(
              goal: g,
              now: now,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => GoalDetailPage(goalId: g.id),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Ringkasan semua target: total terkumpul dan progres keseluruhan.
class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.goals, required this.totalSaved});

  final List<SavingsGoal> goals;
  final double totalSaved;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final target = goals.fold(0.0, (s, g) => s + g.target);
    final reached = goals.where((g) => g.isReached).length;
    final ratio = target == 0 ? 0.0 : totalSaved / target;
    const white = Colors.white;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: p.heroGradient,
        borderRadius: BorderRadius.circular(AppRadius.hero),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconTile(
                icon: Icons.savings_rounded,
                color: white,
                background: Color(0x33FFFFFF),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Total tabungan',
                  style: TextStyle(
                    color: white.withValues(alpha: .9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$reached/${goals.length} tercapai',
                style: TextStyle(
                  color: white.withValues(alpha: .9),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Fmt.rupiah(totalSaved),
              style: const TextStyle(
                color: white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                letterSpacing: -.5,
              ),
            ),
          ),
          Text(
            'dari ${Fmt.rupiah(target)} · ${(ratio * 100).round()}% terkumpul',
            style: TextStyle(
              color: white.withValues(alpha: .85),
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio.clamp(0, 1),
              minHeight: 8,
              color: white,
              backgroundColor: white.withValues(alpha: .25),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu ringkas satu target tabungan.
class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.goal,
    required this.now,
    this.onTap,
  });

  final SavingsGoal goal;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final g = goal;
    final color = Color(g.colorValue);
    final textTheme = Theme.of(context).textTheme;
    final perMonth = g.monthlyNeeded(now);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconTile(
                    icon: CategoryStyle.icons[g.iconKey] ?? Icons.savings,
                    color: color,
                    size: 44,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      g.name,
                      style: textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (g.isReached)
                    Container(
                      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                      decoration: BoxDecoration(
                        color: context.palette.incomeSoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: context.incomeColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Tercapai',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.incomeColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      '${(g.progress * 100).round()}%',
                      style: textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SoftProgress(
                value: g.progress,
                color: g.isReached ? context.incomeColor : color,
              ),
              const SizedBox(height: 10),
              Text(
                '${Fmt.rupiah(g.saved)} dari ${Fmt.rupiah(g.target)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (g.deadline case final d?)
                Text(
                  'Target ${Fmt.month(d)}'
                  '${perMonth == null ? '' : ' · perlu ${Fmt.rupiah(perMonth)}/bulan'}',
                  style: textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
