import 'package:flutter/foundation.dart';

/// Satu notifikasi pengingat yang akan dijadwalkan.
@immutable
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.recurringId,
    required this.fireAt,
    required this.dueDate,
    required this.title,
    required this.body,
  });

  /// ID notifikasi (unik dalam satu jadwal).
  final int id;
  final String recurringId;

  /// Waktu lokal notifikasi dikirim.
  final DateTime fireAt;

  /// Tanggal jatuh tempo transaksi rutin yang diingatkan.
  final DateTime dueDate;
  final String title;
  final String body;

  /// Data yang ikut di notifikasi, agar saat diketuk aplikasi tahu
  /// transaksi rutin & jatuh tempo mana yang dimaksud.
  String get payload => '$recurringId|${dueDate.millisecondsSinceEpoch}';

  /// Kebalikan [payload]; `null` bila format tidak dikenal.
  static ({String recurringId, DateTime dueDate})? parsePayload(
    String? payload,
  ) {
    final parts = payload?.split('|');
    if (parts == null || parts.length != 2) return null;
    final ms = int.tryParse(parts[1]);
    if (ms == null) return null;
    return (
      recurringId: parts[0],
      dueDate: DateTime.fromMillisecondsSinceEpoch(ms),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlannedReminder &&
      other.id == id &&
      other.recurringId == recurringId &&
      other.fireAt == fireAt &&
      other.dueDate == dueDate &&
      other.title == title &&
      other.body == body;

  @override
  int get hashCode =>
      Object.hash(id, recurringId, fireAt, dueDate, title, body);

  @override
  String toString() => 'PlannedReminder($id, $fireAt, $title)';
}
