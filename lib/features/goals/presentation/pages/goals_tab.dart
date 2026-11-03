import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
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
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Belum ada target tabungan.\nKetuk "Target" untuk membuat, '
            'mis. Dana darurat Rp 10.000.000.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.savings_outlined),
            title: const Text('Total tabungan'),
            trailing: Text(
              Fmt.rupiah(totalSaved),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final g in goals)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: .15),
                    child: Icon(CategoryStyle.icons[g.iconKey], color: color),
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
                    const Chip(
                      label: Text('Tercapai'),
                      avatar: Icon(
                        Icons.check_circle,
                        color: Color(0xFF2E7D32),
                      ),
                      visualDensity: VisualDensity.compact,
                    )
                  else
                    Text(
                      '${(g.progress * 100).round()}%',
                      style: textTheme.titleMedium?.copyWith(color: color),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: g.progress,
                  minHeight: 10,
                  color: color,
                  backgroundColor: color.withValues(alpha: .15),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${Fmt.rupiah(g.saved)} dari ${Fmt.rupiah(g.target)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
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
