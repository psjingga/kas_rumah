import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/navigation/home_tab.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/insight_card.dart';
import '../providers/goal_providers.dart';

/// Ringkasan target tabungan untuk tab Ringkasan.
class GoalsOverviewCard extends ConsumerWidget {
  const GoalsOverviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    void open() => ref.read(homeTabProvider.notifier).select(HomeTab.goals);

    if (goals.isEmpty) {
      return InsightCard(
        icon: Icons.savings_outlined,
        title: 'Tabungan',
        value: 'Belum ada target',
        caption: 'Mulai menabung',
        onTap: open,
      );
    }
    final saved = goals.fold(0.0, (s, g) => s + g.saved);
    final target = goals.fold(0.0, (s, g) => s + g.target);
    return InsightCard(
      icon: Icons.savings_outlined,
      title: 'Tabungan',
      value: Fmt.rupiah(saved),
      caption: '${goals.length} target · ${(saved / target * 100).round()}%',
      progress: target == 0 ? 0 : saved / target,
      onTap: open,
    );
  }
}
