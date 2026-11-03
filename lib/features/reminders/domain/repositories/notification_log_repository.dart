import '../entities/notification_entry.dart';
import '../entities/planned_reminder.dart';

/// Penyimpanan riwayat notifikasi dan salinan jadwal yang sedang aktif.
///
/// Notifikasi terjadwal dikirim oleh sistem walau aplikasi tertutup, jadi
/// aplikasi menyimpan salinan jadwalnya; saat aplikasi dibuka, jadwal yang
/// waktunya sudah lewat dipindahkan ke riwayat (inbox).
abstract interface class NotificationLogRepository {
  List<NotificationEntry> loadInbox();

  Future<void> saveInbox(List<NotificationEntry> entries);

  List<PlannedReminder> loadScheduled();

  Future<void> saveScheduled(List<PlannedReminder> reminders);
}
