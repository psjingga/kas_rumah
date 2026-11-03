import '../../../reminders/domain/services/notification_service.dart';
import '../../../reminders/presentation/providers/reminder_providers.dart';
import '../../domain/budget.dart';
import '../../domain/budget_repository.dart';

/// Kirim peringatan anggaran (80% / terlampaui) yang belum pernah dikirim
/// untuk [month]: notifikasi HP + riwayat Notifikasi. Mengembalikan
/// peringatan yang dikirim.
Future<List<BudgetAlert>> dispatchBudgetAlerts({
  required List<BudgetStatus> statuses,
  required DateTime month,
  required BudgetRepository repository,
  required NotificationService notifications,
  required NotificationInboxNotifier inbox,
}) async {
  final sent = repository.getSentAlerts();
  final alerts = pendingBudgetAlerts(
    statuses: statuses,
    month: month,
    sentKeys: sent,
  );
  if (alerts.isEmpty) return alerts;

  for (final a in alerts) {
    await notifications.showNow(
      title: a.title,
      body: a.body,
      // 1000+ agar tidak bentrok dengan ID pengingat rutin (1..60).
      id: 1000 + a.key.hashCode.abs() % 100000,
    );
    await inbox.addNow(title: a.title, body: a.body);
  }
  // Simpan hanya kunci bulan berjalan supaya daftar tidak terus membesar.
  final prefix = '${month.year}-${month.month}|';
  await repository.saveSentAlerts({
    for (final k in sent)
      if (k.startsWith(prefix)) k,
    for (final a in alerts) a.key,
  });
  return alerts;
}
