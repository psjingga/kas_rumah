import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../transactions/presentation/providers/recurring_providers.dart';
import '../../../transactions/presentation/providers/transaction_providers.dart';
import '../../domain/entities/notification_entry.dart';
import '../../domain/entities/planned_reminder.dart';
import '../../domain/entities/reminder_settings.dart';
import '../../domain/repositories/notification_log_repository.dart';
import '../../domain/repositories/reminder_settings_repository.dart';
import '../../domain/services/notification_service.dart';
import '../../domain/services/reminder_planner.dart';

/// Layanan notifikasi; di-override di `main()` / tes.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => throw UnimplementedError(
    'notificationServiceProvider harus di-override di ProviderScope',
  ),
);

final reminderSettingsRepositoryProvider = Provider<ReminderSettingsRepository>(
  (ref) => throw UnimplementedError(
    'reminderSettingsRepositoryProvider harus di-override di ProviderScope',
  ),
);

final notificationLogRepositoryProvider = Provider<NotificationLogRepository>(
  (ref) => throw UnimplementedError(
    'notificationLogRepositoryProvider harus di-override di ProviderScope',
  ),
);

final reminderSettingsProvider =
    NotifierProvider<ReminderSettingsNotifier, ReminderSettings>(
      ReminderSettingsNotifier.new,
    );

/// Jadwal pengingat terbaru. Otomatis dihitung ulang bila transaksi rutin,
/// transaksi, atau pengaturan berubah; `main()` mendengarkan provider ini
/// dan menyinkronkannya ke [NotificationService].
final plannedRemindersProvider = Provider<List<PlannedReminder>>(
  (ref) => planReminders(
    recurring: ref.watch(recurringProvider),
    transactions: ref.watch(transactionsProvider),
    settings: ref.watch(reminderSettingsProvider),
    now: ref.read(clockProvider)(),
  ),
);

class ReminderSettingsNotifier extends Notifier<ReminderSettings> {
  @override
  ReminderSettings build() =>
      ref.watch(reminderSettingsRepositoryProvider).load();

  Future<void> update(ReminderSettings settings) async {
    await ref.read(reminderSettingsRepositoryProvider).save(settings);
    state = settings;
  }
}

/// Riwayat notifikasi yang sudah diterima (terbaru lebih dulu).
final notificationInboxProvider =
    NotifierProvider<NotificationInboxNotifier, List<NotificationEntry>>(
      NotificationInboxNotifier.new,
    );

/// Jumlah notifikasi belum dibaca, untuk badge lonceng.
final unreadNotificationsProvider = Provider<int>(
  (ref) => ref.watch(notificationInboxProvider).where((e) => !e.read).length,
);

class NotificationInboxNotifier extends Notifier<List<NotificationEntry>> {
  /// Riwayat disimpan paling banyak sekian notifikasi terbaru.
  static const maxEntries = 100;

  NotificationLogRepository get _repository =>
      ref.read(notificationLogRepositoryProvider);

  @override
  List<NotificationEntry> build() =>
      _sorted(ref.watch(notificationLogRepositoryProvider).loadInbox());

  /// Pindahkan pengingat terjadwal yang waktunya sudah lewat (berarti sudah
  /// dikirim sistem) ke riwayat. Dipanggil saat aplikasi dibuka/kembali
  /// aktif dan sebelum jadwal diganti.
  ///
  /// Bila izin notifikasi dimatikan, pengingat itu tidak pernah tampil di
  /// HP, jadi dibuang tanpa dicatat ke riwayat.
  Future<void> collectDelivered() async {
    final now = ref.read(clockProvider)();
    final scheduled = _repository.loadScheduled();
    final delivered = scheduled.where((r) => !r.fireAt.isAfter(now));
    if (delivered.isEmpty) return;

    final shown = await ref
        .read(notificationServiceProvider)
        .isPermissionGranted();
    final known = {for (final e in state) e.id};
    if (shown) {
      await _save([
        for (final r in delivered)
          if (!known.contains(_idOf(r)))
            NotificationEntry(
              id: _idOf(r),
              title: r.title,
              body: r.body,
              time: r.fireAt,
              recurringId: r.recurringId,
              dueDate: r.dueDate,
            ),
        ...state,
      ]);
    }
    await _repository.saveScheduled([
      for (final r in scheduled)
        if (r.fireAt.isAfter(now)) r,
    ]);
  }

  /// Catat riwayat yang sudah terkirim, lalu simpan [plan] sebagai jadwal
  /// aktif yang baru.
  Future<void> syncSchedule(List<PlannedReminder> plan) async {
    await collectDelivered();
    await _repository.saveScheduled(plan);
  }

  /// Tandai pengingat dari [payload] notifikasi sebagai sudah dibaca.
  Future<void> markReadByPayload(String? payload) async {
    final p = PlannedReminder.parsePayload(payload);
    if (p == null) return;
    await collectDelivered();
    await markRead(
      'rutin-${p.recurringId}-${p.dueDate.millisecondsSinceEpoch}',
    );
  }

  /// Notifikasi yang langsung dikirim (mis. notifikasi uji).
  Future<void> addNow({required String title, required String body}) {
    final now = ref.read(clockProvider)();
    return _save([
      NotificationEntry(
        id: 'now-${now.microsecondsSinceEpoch}',
        title: title,
        body: body,
        time: now,
      ),
      ...state,
    ]);
  }

  Future<void> markRead(String id) =>
      _save([for (final e in state) e.id == id ? e.markRead() : e]);

  Future<void> markAllRead() => _save([for (final e in state) e.markRead()]);

  Future<void> clear() => _save(const []);

  Future<void> _save(List<NotificationEntry> entries) async {
    final next = _sorted(entries).take(maxEntries).toList();
    await _repository.saveInbox(next);
    state = next;
  }

  /// Satu entri per transaksi rutin per jatuh tempo (tidak dobel).
  static String _idOf(PlannedReminder r) =>
      'rutin-${r.recurringId}-${r.dueDate.millisecondsSinceEpoch}';

  static List<NotificationEntry> _sorted(List<NotificationEntry> list) =>
      [...list]..sort((a, b) => b.time.compareTo(a.time));
}
