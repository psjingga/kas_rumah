import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/entities/planned_reminder.dart';
import '../domain/services/notification_service.dart';

/// [NotificationService] berbasis flutter_local_notifications.
///
/// Memakai jadwal *inexact* (Android boleh menggeser beberapa menit demi
/// hemat baterai) sehingga tidak perlu izin "alarm tepat waktu".
class LocalNotificationService implements NotificationService {
  LocalNotificationService([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  void Function(String? payload)? onTap;

  /// Antrean agar sinkronisasi beruntun tidak saling tumpang tindih.
  Future<void> _queue = Future.value();

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'pengingat_rutin',
      'Pengingat transaksi rutin',
      channelDescription: 'Pengingat tagihan & pemasukan rutin bulanan',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  @override
  Future<void> init() async {
    tzdata.initializeTimeZones();
    try {
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (e) {
      // Zona waktu tidak dikenali → asumsikan WIB.
      debugPrint('Zona waktu lokal gagal dibaca ($e), memakai Asia/Jakarta');
      tz.setLocalLocation(tz.getLocation('Asia/Jakarta'));
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Izin iOS diminta lewat [requestPermission], bukan saat init.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) => onTap?.call(r.payload),
    );
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  @override
  Future<bool> isPermissionGranted() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return (await ios?.checkPermissions())?.isEnabled ?? false;
  }

  @override
  Future<void> openSettings() => _plugin.openAppNotificationSettings();

  @override
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true
        ? details?.notificationResponse?.payload
        : null;
  }

  @override
  Future<void> replaceSchedule(List<PlannedReminder> reminders) =>
      _queue = _queue.then((_) async {
        try {
          await _plugin.cancelAllPendingNotifications();
          for (final r in reminders) {
            await _plugin.zonedSchedule(
              id: r.id,
              title: r.title,
              body: r.body,
              payload: r.payload,
              scheduledDate: tz.TZDateTime.from(r.fireAt, tz.local),
              notificationDetails: _details,
              androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            );
          }
        } catch (e) {
          // Gagal menjadwalkan tidak boleh membuat aplikasi crash.
          debugPrint('Gagal menjadwalkan pengingat: $e');
        }
      });

  @override
  Future<void> showNow({
    required String title,
    required String body,
    int id = 0,
  }) => _plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: _details,
  );
}
