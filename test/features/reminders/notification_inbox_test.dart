import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:keuangan_rumah_tangga/features/reminders/data/hive_notification_log_repository.dart';
import 'package:keuangan_rumah_tangga/features/reminders/domain/entities/notification_entry.dart';
import 'package:keuangan_rumah_tangga/features/reminders/presentation/providers/reminder_providers.dart';

import '../transactions/fakes.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  test('pengingat yang sudah lewat masuk riwayat, tanpa dobel', () async {
    var now = today;
    final log = InMemoryNotificationLogRepository();
    final c = ProviderContainer(
      overrides: testOverrides(
        InMemoryTransactionRepository(),
        InMemoryRecurringRepository([listrik()]),
        null,
        log,
        () => now,
      ),
    );
    addTearDown(c.dispose);
    final inbox = c.read(notificationInboxProvider.notifier);

    // Sinkron awal: 3 jadwal (Nov, Des, Jan), belum ada yang terkirim.
    await inbox.syncSchedule(c.read(plannedRemindersProvider));
    expect(log.scheduled, hasLength(3));
    expect(c.read(notificationInboxProvider), isEmpty);

    // 4 Nov 09.00: pengingat H-1 08.00 sudah terkirim.
    now = DateTime(2026, 11, 4, 9);
    await inbox.collectDelivered();
    final entry = c.read(notificationInboxProvider).single;
    expect(entry.title, 'Tagihan rutin: Listrik');
    expect(entry.time, DateTime(2026, 11, 4, 8));
    expect(entry.dueDate, DateTime(2026, 11, 5));
    expect(c.read(unreadNotificationsProvider), 1);
    expect(log.scheduled, hasLength(2));

    await inbox.collectDelivered();
    expect(c.read(notificationInboxProvider), hasLength(1));

    await inbox.markRead(entry.id);
    expect(c.read(unreadNotificationsProvider), 0);

    await inbox.addNow(title: 'Uji', body: 'x');
    expect(c.read(notificationInboxProvider).first.title, 'Uji');
    await inbox.markAllRead();
    expect(c.read(unreadNotificationsProvider), 0);

    await inbox.clear();
    expect(log.inbox, isEmpty);
  });

  test('Hive: riwayat & jadwal tersimpan', () async {
    final dir = await Directory.systemTemp.createTemp('hive_notif');
    addTearDown(() => dir.delete(recursive: true));
    Hive.init(dir.path);
    final box = await Hive.openBox<dynamic>('settings');
    addTearDown(Hive.close);
    final repo = HiveNotificationLogRepository(box);

    final entry = NotificationEntry(
      id: 'a',
      title: 'Judul',
      body: 'Isi',
      time: DateTime(2026, 11, 4, 8),
      recurringId: 'listrik',
      dueDate: DateTime(2026, 11, 5),
    );
    await repo.saveInbox([entry, entry.markRead()]);
    expect(repo.loadInbox(), [entry, entry.markRead()]);
    expect(repo.loadScheduled(), isEmpty);
  });
}
