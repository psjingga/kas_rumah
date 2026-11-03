import '../entities/reminder_settings.dart';

/// Kontrak penyimpanan pengaturan pengingat.
abstract interface class ReminderSettingsRepository {
  ReminderSettings load();

  Future<void> save(ReminderSettings settings);
}
