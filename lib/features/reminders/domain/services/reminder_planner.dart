import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/month.dart';
import '../../../transactions/domain/entities/recurring_transaction.dart';
import '../../../transactions/domain/entities/transaction.dart';
import '../../../debts/domain/debt.dart';
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
  Iterable<Debt> debts = const [],
  int monthsAhead = 3,
  int limit = 60,
}) {
  if (!settings.enabled) return const [];

  final planned = <(DateTime, RecurringTransaction, DateTime)>[];
  for (final r in recurring) {
    for (var i = 0; i < monthsAhead; i++) {
      for (final o in r.occurrencesIn(now.firstOfMonth.addMonths(i))) {
        if (r.isRecordedIn(transactions, o.date)) continue;

        final due = o.date;
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
  }
  // Utang/piutang belum lunas yang punya jatuh tempo.
  final debtPlans = <(DateTime, Debt)>[
    for (final d in debts)
      if (!d.isSettled && d.dueDate != null)
        if (DateTime(
              d.dueDate!.year,
              d.dueDate!.month,
              d.dueDate!.day - settings.daysBefore,
              settings.hour,
              settings.minute,
            )
            case final fireAt when fireAt.isAfter(now))
          (fireAt, d),
  ];

  final all = <(DateTime, PlannedReminder Function(int id))>[
    for (final (fireAt, r, due) in planned)
      (
        fireAt,
        (id) => PlannedReminder(
          id: id,
          recurringId: r.id,
          fireAt: fireAt,
          dueDate: due,
          title: '${r.isIncome ? 'Pemasukan' : 'Tagihan'} rutin: ${r.title}',
          body:
              '${_when(settings.daysBefore)} (${Fmt.date(due)}) · '
              '${Fmt.rupiah(r.amount)}. Buka aplikasi untuk mencatat.',
        ),
      ),
    for (final (fireAt, d) in debtPlans)
      (
        fireAt,
        (id) => PlannedReminder(
          id: id,
          recurringId: '$debtReminderPrefix${d.id}',
          fireAt: fireAt,
          dueDate: d.dueDate!,
          title: '${d.iOwe ? 'Utang' : 'Piutang'}: ${d.person}',
          body:
              '${_when(settings.daysBefore)} (${Fmt.date(d.dueDate!)}) · '
              'sisa ${Fmt.rupiah(d.remaining)}.',
        ),
      ),
  ]..sort((a, b) => a.$1.compareTo(b.$1));

  // ID berurutan; jadwal lama selalu dibatalkan sebelum dijadwalkan ulang,
  // jadi ID tidak perlu stabil antar-sinkronisasi.
  return [for (final (i, (_, build)) in all.take(limit).indexed) build(i + 1)];
}

/// Awalan `recurringId` pengingat utang/piutang: `debt:<id>`.
const debtReminderPrefix = 'debt:';

String _when(int daysBefore) => switch (daysBefore) {
  0 => 'Jatuh tempo hari ini',
  1 => 'Jatuh tempo besok',
  final n => 'Jatuh tempo $n hari lagi',
};
