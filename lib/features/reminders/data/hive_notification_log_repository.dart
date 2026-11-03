import 'package:hive_ce/hive_ce.dart';

import '../domain/entities/notification_entry.dart';
import '../domain/entities/planned_reminder.dart';
import '../domain/repositories/notification_log_repository.dart';

/// Menyimpan riwayat & jadwal notifikasi sebagai list map di box `settings`.
class HiveNotificationLogRepository implements NotificationLogRepository {
  const HiveNotificationLogRepository(this._box);

  final Box<dynamic> _box;

  static const _inboxKey = 'notification_inbox';
  static const _scheduledKey = 'notification_scheduled';

  List<Map<dynamic, dynamic>> _maps(String key) =>
      (_box.get(key) as List?)?.whereType<Map<dynamic, dynamic>>().toList() ??
      const [];

  static DateTime? _date(Object? ms) =>
      ms is int ? DateTime.fromMillisecondsSinceEpoch(ms) : null;

  @override
  List<NotificationEntry> loadInbox() => [
    for (final m in _maps(_inboxKey))
      NotificationEntry(
        id: m['id'] as String,
        title: m['title'] as String,
        body: m['body'] as String,
        time: _date(m['time'])!,
        recurringId: m['recurringId'] as String?,
        dueDate: _date(m['dueDate']),
        read: m['read'] as bool? ?? false,
      ),
  ];

  @override
  Future<void> saveInbox(List<NotificationEntry> entries) =>
      _box.put(_inboxKey, [
        for (final e in entries)
          {
            'id': e.id,
            'title': e.title,
            'body': e.body,
            'time': e.time.millisecondsSinceEpoch,
            'recurringId': e.recurringId,
            'dueDate': e.dueDate?.millisecondsSinceEpoch,
            'read': e.read,
          },
      ]);

  @override
  List<PlannedReminder> loadScheduled() => [
    for (final m in _maps(_scheduledKey))
      PlannedReminder(
        id: m['id'] as int,
        recurringId: m['recurringId'] as String,
        fireAt: _date(m['fireAt'])!,
        dueDate: _date(m['dueDate'])!,
        title: m['title'] as String,
        body: m['body'] as String,
      ),
  ];

  @override
  Future<void> saveScheduled(List<PlannedReminder> reminders) =>
      _box.put(_scheduledKey, [
        for (final r in reminders)
          {
            'id': r.id,
            'recurringId': r.recurringId,
            'fireAt': r.fireAt.millisecondsSinceEpoch,
            'dueDate': r.dueDate.millisecondsSinceEpoch,
            'title': r.title,
            'body': r.body,
          },
      ]);
}
