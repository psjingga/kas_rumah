import 'package:hive_ce/hive_ce.dart';

import '../domain/entities/reminder_settings.dart';
import '../domain/repositories/reminder_settings_repository.dart';

/// Menyimpan [ReminderSettings] sebagai map biasa di box `settings`
/// (tanpa adapter khusus).
class HiveReminderSettingsRepository implements ReminderSettingsRepository {
  const HiveReminderSettingsRepository(this._box);

  final Box<dynamic> _box;

  static const _key = 'reminder';

  @override
  ReminderSettings load() {
    final m = _box.get(_key);
    if (m is! Map) return const ReminderSettings();
    const d = ReminderSettings();
    return ReminderSettings(
      enabled: m['enabled'] as bool? ?? d.enabled,
      daysBefore: m['daysBefore'] as int? ?? d.daysBefore,
      hour: m['hour'] as int? ?? d.hour,
      minute: m['minute'] as int? ?? d.minute,
      budgetAlerts: m['budgetAlerts'] as bool? ?? d.budgetAlerts,
    );
  }

  @override
  Future<void> save(ReminderSettings s) => _box.put(_key, {
    'enabled': s.enabled,
    'daysBefore': s.daysBefore,
    'hour': s.hour,
    'minute': s.minute,
    'budgetAlerts': s.budgetAlerts,
  });
}
