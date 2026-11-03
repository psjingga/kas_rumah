import '../entities/planned_reminder.dart';

/// Kontrak layanan notifikasi lokal. Implementasi asli memakai
/// flutter_local_notifications; di tes diganti versi palsu.
abstract interface class NotificationService {
  /// Siapkan plugin & zona waktu. Panggil sekali sebelum dipakai.
  Future<void> init();

  /// Minta izin notifikasi (Android 13+ / iOS). `true` bila diizinkan.
  Future<bool> requestPermission();

  /// Apakah notifikasi aplikasi ini diizinkan (tanpa memunculkan dialog).
  Future<bool> isPermissionGranted();

  /// Buka halaman pengaturan notifikasi aplikasi di HP.
  Future<void> openSettings();

  /// Dipanggil dengan `payload` saat pengguna mengetuk notifikasi.
  set onTap(void Function(String? payload)? handler);

  /// `payload` notifikasi yang membuka aplikasi dari keadaan tertutup.
  Future<String?> launchPayload();

  /// Batalkan semua pengingat terjadwal lalu jadwalkan [reminders].
  Future<void> replaceSchedule(List<PlannedReminder> reminders);

  /// Tampilkan notifikasi saat ini juga (uji coba, peringatan anggaran).
  /// [id] di bawah 1 atau di atas 1000 agar tidak bentrok dengan pengingat.
  Future<void> showNow({
    required String title,
    required String body,
    int id = 0,
  });
}
