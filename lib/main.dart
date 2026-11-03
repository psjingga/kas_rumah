import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'core/database/hive_database.dart';
import 'core/utils/month.dart';
import 'features/budgets/data/hive_budget_repository.dart';
import 'features/budgets/presentation/providers/budget_alerts.dart';
import 'features/budgets/presentation/providers/budget_providers.dart';
import 'features/goals/data/hive_goal_repository.dart';
import 'features/goals/presentation/providers/goal_providers.dart';
import 'features/reminders/data/hive_notification_log_repository.dart';
import 'features/reminders/data/hive_reminder_settings_repository.dart';
import 'features/reminders/data/local_notification_service.dart';
import 'features/reminders/presentation/notification_navigation.dart';
import 'features/reminders/presentation/providers/reminder_providers.dart';
import 'features/settings/data/hive_settings_repositories.dart';
import 'features/settings/data/local_biometric_auth.dart';
import 'features/settings/presentation/providers/settings_providers.dart';
import 'features/transactions/data/repositories/hive_category_repository.dart';
import 'features/transactions/data/repositories/hive_recurring_repository.dart';
import 'features/transactions/data/repositories/hive_transaction_repository.dart';
import 'features/transactions/presentation/providers/category_providers.dart';
import 'features/transactions/presentation/providers/recurring_providers.dart';
import 'features/transactions/presentation/providers/transaction_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Data format tanggal Indonesia ("3 Nov 2026"), database lokal, dan
  // plugin notifikasi.
  await initializeDateFormatting('id_ID');
  final boxes = await HiveDatabase.init();
  final notifications = LocalNotificationService();
  await notifications.init();

  // Suntikkan implementasi asli (Hive, plugin notifikasi, biometrik).
  final settings = boxes.settings;
  final container = ProviderContainer(
    overrides: [
      transactionRepositoryProvider.overrideWithValue(
        HiveTransactionRepository(boxes.transactions),
      ),
      recurringRepositoryProvider.overrideWithValue(
        HiveRecurringRepository(boxes.recurring),
      ),
      categoryRepositoryProvider.overrideWithValue(
        HiveCategoryRepository(settings),
      ),
      budgetRepositoryProvider.overrideWithValue(
        HiveBudgetRepository(settings),
      ),
      goalRepositoryProvider.overrideWithValue(HiveGoalRepository(settings)),
      reminderSettingsRepositoryProvider.overrideWithValue(
        HiveReminderSettingsRepository(settings),
      ),
      notificationLogRepositoryProvider.overrideWithValue(
        HiveNotificationLogRepository(settings),
      ),
      notificationServiceProvider.overrideWithValue(notifications),
      preferencesRepositoryProvider.overrideWithValue(
        HivePreferencesRepository(settings),
      ),
      securityRepositoryProvider.overrideWithValue(
        HiveSecurityRepository(settings),
      ),
      biometricAuthProvider.overrideWithValue(LocalBiometricAuth()),
    ],
  );

  runApp(
    UncontrolledProviderScope(container: container, child: const KeuanganApp()),
  );

  final inbox = container.read(notificationInboxProvider.notifier);

  // Notifikasi diketuk saat aplikasi terbuka / di latar belakang, atau
  // notifikasi yang membuka aplikasi dari keadaan tertutup.
  notifications.onTap = (payload) =>
      openFromNotification(container, appNavigatorKey.currentState, payload);
  if (await notifications.launchPayload() case final payload?) {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => openFromNotification(
        container,
        appNavigatorKey.currentState,
        payload,
      ),
    );
  }

  // Setiap kali jadwal pengingat berubah (transaksi rutin ditambah/diubah,
  // dicatat, atau pengaturan diganti): pindahkan yang sudah terkirim ke
  // riwayat Notifikasi, lalu jadwalkan ulang.
  // Izin diminta sekali per sesi saat memang ada pengingat yang akan
  // dikirim (Android 13+ hanya menampilkan dialog jika belum diputuskan).
  var permissionAsked = false;
  container.listen(plannedRemindersProvider, (_, reminders) {
    inbox.syncSchedule(reminders);
    notifications.replaceSchedule(reminders);
    if (reminders.isNotEmpty && !permissionAsked) {
      permissionAsked = true;
      notifications.requestPermission();
    }
  }, fireImmediately: true);

  // Peringatan anggaran bulan berjalan (80% & terlampaui), sekali per
  // kategori per tingkat.
  container.listen(currentBudgetStatusProvider, (_, statuses) {
    if (!container.read(reminderSettingsProvider).budgetAlerts) return;
    dispatchBudgetAlerts(
      statuses: statuses,
      month: container.read(clockProvider)().firstOfMonth,
      repository: container.read(budgetRepositoryProvider),
      notifications: notifications,
      inbox: inbox,
    );
  }, fireImmediately: true);

  // Notifikasi dikirim sistem walau aplikasi tertutup; perbarui riwayat
  // saat aplikasi kembali dibuka dan tiap menit selama aplikasi terbuka.
  AppLifecycleListener(onResume: inbox.collectDelivered);
  Timer.periodic(const Duration(minutes: 1), (_) => inbox.collectDelivered());
}
