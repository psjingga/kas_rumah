import 'package:flutter/foundation.dart';

/// Satu notifikasi yang sudah diterima, untuk halaman Notifikasi.
@immutable
class NotificationEntry {
  const NotificationEntry({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    this.recurringId,
    this.dueDate,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;

  /// Waktu notifikasi dikirim.
  final DateTime time;

  /// Transaksi rutin yang diingatkan (null untuk notifikasi uji).
  final String? recurringId;
  final DateTime? dueDate;
  final bool read;

  NotificationEntry markRead() => NotificationEntry(
    id: id,
    title: title,
    body: body,
    time: time,
    recurringId: recurringId,
    dueDate: dueDate,
    read: true,
  );

  @override
  bool operator ==(Object other) =>
      other is NotificationEntry &&
      other.id == id &&
      other.title == title &&
      other.body == body &&
      other.time == time &&
      other.recurringId == recurringId &&
      other.dueDate == dueDate &&
      other.read == read;

  @override
  int get hashCode =>
      Object.hash(id, title, body, time, recurringId, dueDate, read);
}
