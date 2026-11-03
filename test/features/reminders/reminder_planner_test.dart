import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:keuangan_rumah_tangga/features/reminders/domain/entities/reminder_settings.dart';
import 'package:keuangan_rumah_tangga/features/reminders/domain/services/reminder_planner.dart';
import 'package:keuangan_rumah_tangga/features/transactions/domain/entities/transaction.dart';

import '../transactions/fakes.dart';

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  // Listrik jatuh tempo tgl 5; hari ini 3 Nov 2026 pukul 09.00.
  List<DateTime> fireTimes({
    List<Transaction> transactions = const [],
    ReminderSettings settings = const ReminderSettings(),
    DateTime? now,
  }) => [
    for (final r in planReminders(
      recurring: [listrik()],
      transactions: transactions,
      settings: settings,
      now: now ?? today,
    ))
      r.fireAt,
  ];

  test('H-1 pukul 08.00 untuk 3 bulan ke depan', () {
    final plan = planReminders(
      recurring: [listrik()],
      transactions: const [],
      settings: const ReminderSettings(),
      now: today,
    );
    expect(plan.map((r) => r.fireAt), [
      DateTime(2026, 11, 4, 8),
      DateTime(2026, 12, 4, 8),
      DateTime(2027, 1, 4, 8),
    ]);
    expect(plan.map((r) => r.id), [1, 2, 3]);
    expect(plan.first.title, 'Tagihan rutin: Listrik');
    expect(
      plan.first.body,
      'Jatuh tempo besok (5 Nov 2026) · Rp 450.000. '
      'Buka aplikasi untuk mencatat.',
    );
  });

  test('bulan yang sudah dicatat dilewati', () {
    final dicatat = tx(
      'x',
      450000,
      TransactionCategory.bills,
      date: DateTime(2026, 11, 5),
      recurringId: 'listrik',
    );
    expect(fireTimes(transactions: [dicatat]).first, DateTime(2026, 12, 4, 8));
  });

  test('waktu yang sudah lewat dilewati', () {
    expect(
      fireTimes(now: DateTime(2026, 11, 4, 8, 1)).first,
      DateTime(2026, 12, 4, 8),
    );
  });

  test('mengikuti pengaturan hari & jam', () {
    expect(
      fireTimes(
        settings: const ReminderSettings(daysBefore: 0, hour: 19, minute: 30),
      ).first,
      DateTime(2026, 11, 5, 19, 30),
    );
    final plan = planReminders(
      recurring: [listrik()],
      transactions: const [],
      settings: const ReminderSettings(daysBefore: 3),
      now: today,
    );
    // 5 Nov − 3 hari = 2 Nov (sudah lewat) → mulai Desember.
    expect(plan.first.fireAt, DateTime(2026, 12, 2, 8));
    expect(plan.first.body, startsWith('Jatuh tempo 3 hari lagi'));
  });

  test('mati, template nonaktif, atau belum mulai → tanpa pengingat', () {
    expect(
      fireTimes(settings: const ReminderSettings(enabled: false)),
      isEmpty,
    );
    expect(
      planReminders(
        recurring: [listrik().copyWith(active: false)],
        transactions: const [],
        settings: const ReminderSettings(),
        now: today,
      ),
      isEmpty,
    );
    expect(
      planReminders(
        recurring: [listrik().copyWith(startMonth: DateTime(2027, 1))],
        transactions: const [],
        settings: const ReminderSettings(),
        now: today,
      ).map((r) => r.fireAt),
      [DateTime(2027, 1, 4, 8)],
    );
  });

  test('dibatasi jumlah maksimum, urut waktu terdekat', () {
    final plan = planReminders(
      recurring: [
        listrik(),
        listrik(day: 20).copyWith(title: 'Air'),
      ],
      transactions: const [],
      settings: const ReminderSettings(),
      now: today,
      limit: 2,
    );
    expect(plan.map((r) => r.fireAt), [
      DateTime(2026, 11, 4, 8),
      DateTime(2026, 11, 19, 8),
    ]);
  });
}
