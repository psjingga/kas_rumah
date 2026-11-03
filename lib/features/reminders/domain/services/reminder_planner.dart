import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/month.dart';
import '../../../transactions/domain/entities/recurring_transaction.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../entities/planned_reminder.dart';
import '../entities/reminder_settings.dart';

/// Menyusun jadwal pengingat dari transaksi rutin.
///
/// Fungsi murni (tanpa plugin), sehingga mudah diuji. Aturannya:
/// - hanya template aktif, untuk bulan ini s/d [monthsAhead] bulan ke depan;
/// - dilewati bila transaksi rutin bulan itu **sudah dicatat**;
/// - dilewati bila waktu pengingat sudah lewat;
/// - maksimal [limit] pengingat terdekat (batas alarm di Android).
List<PlannedReminder> planReminders({
  required Iterable<RecurringTransaction> recurring,
  required Iterable<Transaction> transactions,
  required ReminderSettings settings,
  required DateTime now,
  int monthsAhead = 3,
  int limit = 60,
}) {
  if (!settings.enabled) return const [];

  // Pasangan (template, bulan) yang sudah dicatat.
  final recorded = {
    for (final t in transactions)
      if (t.recurringId case final id?) (id, t.date.firstOfMonth),
  };

  final planned = <(DateTime, RecurringTransaction, DateTime)>[];
  for (final r in recurring) {
    for (var i = 0; i < monthsAhead; i++) {
      final month = now.firstOfMonth.addMonths(i);
      if (!r.appliesTo(month) || recorded.contains((r.id, month))) continue;

      final due = r.dueDate(month);
      final fireAt = DateTime(
        due.year,
        due.month,
        due.day - settings.daysBefore,
        settings.hour,
        settings.minute,
      );
      if (fireAt.isAfter(now)) planned.add((fireAt, r, due));
    }
  }
  planned.sort((a, b) => a.$1.compareTo(b.$1));

  return [
    for (final (i, (fireAt, r, due)) in planned.take(limit).indexed)
      PlannedReminder(
        // ID berurutan; jadwal lama selalu dibatalkan sebelum dijadwalkan
        // ulang, jadi ID tidak perlu stabil antar-sinkronisasi.
        id: i + 1,
        recurringId: r.id,
        fireAt: fireAt,
        dueDate: due,
        title: '${r.isIncome ? 'Pemasukan' : 'Tagihan'} rutin: ${r.title}',
        body:
            '${_when(settings.daysBefore)} (${Fmt.date(due)}) · '
            '${Fmt.rupiah(r.amount)}. Buka aplikasi untuk mencatat.',
      ),
  ];
}

String _when(int daysBefore) => switch (daysBefore) {
  0 => 'Jatuh tempo hari ini',
  1 => 'Jatuh tempo besok',
  final n => 'Jatuh tempo $n hari lagi',
};
