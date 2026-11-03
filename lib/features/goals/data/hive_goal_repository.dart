import 'package:hive_ce/hive_ce.dart';

import '../domain/goal_repository.dart';
import '../domain/savings_goal.dart';

/// Menyimpan target tabungan sebagai list map di box `settings`.
class HiveGoalRepository implements GoalRepository {
  const HiveGoalRepository(this._box);

  final Box<dynamic> _box;

  static const _key = 'savings_goals';

  static Map<String, Object?> toMap(SavingsGoal g) => {
    'id': g.id,
    'name': g.name,
    'target': g.target,
    'iconKey': g.iconKey,
    'color': g.colorValue,
    'deadline': g.deadline?.millisecondsSinceEpoch,
    'deposits': [
      for (final d in g.deposits)
        {
          'id': d.id,
          'amount': d.amount,
          'date': d.date.millisecondsSinceEpoch,
          'transactionId': d.transactionId,
        },
    ],
  };

  static SavingsGoal fromMap(Map<dynamic, dynamic> m) => SavingsGoal(
    id: m['id'] as String,
    name: m['name'] as String,
    target: (m['target'] as num).toDouble(),
    iconKey: m['iconKey'] as String,
    colorValue: m['color'] as int,
    deadline: switch (m['deadline']) {
      final int ms => DateTime.fromMillisecondsSinceEpoch(ms),
      _ => null,
    },
    deposits: [
      for (final d
          in (m['deposits'] as List? ?? const [])
              .whereType<Map<dynamic, dynamic>>())
        GoalDeposit(
          id: d['id'] as String,
          amount: (d['amount'] as num).toDouble(),
          date: DateTime.fromMillisecondsSinceEpoch(d['date'] as int),
          transactionId: d['transactionId'] as String?,
        ),
    ],
  );

  @override
  List<SavingsGoal> getAll() => [
    for (final m
        in (_box.get(_key) as List? ?? const [])
            .whereType<Map<dynamic, dynamic>>())
      fromMap(m),
  ];

  @override
  Future<void> replaceAll(List<SavingsGoal> goals) =>
      _box.put(_key, [for (final g in goals) toMap(g)]);
}
