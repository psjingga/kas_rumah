import 'package:hive_ce/hive_ce.dart';

import '../domain/budget_repository.dart';

/// Menyimpan anggaran sebagai map di box `settings`.
class HiveBudgetRepository implements BudgetRepository {
  const HiveBudgetRepository(this._box);

  final Box<dynamic> _box;

  static const _limitsKey = 'budgets';
  static const _alertsKey = 'budget_alerts';

  @override
  Map<String, double> getLimits() => {
    for (final MapEntry(:key, :value)
        in ((_box.get(_limitsKey) as Map?) ?? const {}).entries)
      key as String: (value as num).toDouble(),
  };

  @override
  Future<void> replaceLimits(Map<String, double> limits) =>
      _box.put(_limitsKey, limits);

  @override
  Set<String> getSentAlerts() => {
    ...?(_box.get(_alertsKey) as List?)?.whereType<String>(),
  };

  @override
  Future<void> saveSentAlerts(Set<String> keys) =>
      _box.put(_alertsKey, keys.toList());
}
