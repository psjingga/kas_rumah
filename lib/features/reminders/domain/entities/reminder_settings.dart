import 'package:flutter/foundation.dart';

/// Pengaturan notifikasi pengingat transaksi rutin.
@immutable
class ReminderSettings {
  const ReminderSettings({
    this.enabled = true,
    this.daysBefore = 1,
    this.hour = 8,
    this.minute = 0,
    this.budgetAlerts = true,
  });

  final bool enabled;

  /// Berapa hari sebelum jatuh tempo (0 = di hari jatuh tempo).
  final int daysBefore;

  /// Jam pengingat dikirim (waktu lokal HP).
  final int hour;
  final int minute;

  /// Kirim peringatan saat anggaran mencapai 80% dan 100%.
  final bool budgetAlerts;

  /// Pilihan [daysBefore] yang ditawarkan di pengaturan.
  static const daysBeforeOptions = [0, 1, 2, 3, 7];

  /// "Hari H" / "H-1" / "H-3".
  static String daysBeforeLabel(int days) => days == 0 ? 'Hari H' : 'H-$days';

  /// "08.00".
  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}.${minute.toString().padLeft(2, '0')}';

  ReminderSettings copyWith({
    bool? enabled,
    int? daysBefore,
    int? hour,
    int? minute,
    bool? budgetAlerts,
  }) => ReminderSettings(
    enabled: enabled ?? this.enabled,
    daysBefore: daysBefore ?? this.daysBefore,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    budgetAlerts: budgetAlerts ?? this.budgetAlerts,
  );

  @override
  bool operator ==(Object other) =>
      other is ReminderSettings &&
      other.enabled == enabled &&
      other.daysBefore == daysBefore &&
      other.hour == hour &&
      other.minute == minute &&
      other.budgetAlerts == budgetAlerts;

  @override
  int get hashCode =>
      Object.hash(enabled, daysBefore, hour, minute, budgetAlerts);
}
