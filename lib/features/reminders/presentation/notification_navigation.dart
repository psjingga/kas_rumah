import 'package:flutter/material.dart';
import '../domain/services/reminder_planner.dart';
import '../../debts/presentation/providers/debt_providers.dart';
import '../../debts/presentation/pages/debt_pages.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/month.dart';
import '../../transactions/presentation/pages/transaction_form_page.dart';
import '../../transactions/presentation/providers/recurring_providers.dart';
import '../../transactions/presentation/providers/transaction_providers.dart';
import '../domain/entities/planned_reminder.dart';
import 'pages/notifications_page.dart';
import 'providers/reminder_providers.dart';

/// Tindak lanjut saat notifikasi pengingat diketuk di HP: tandai dibaca,
/// lalu langsung buka form "Catat" bila transaksi rutinnya belum dicatat;
/// selain itu buka halaman Notifikasi.
Future<void> openFromNotification(
  ProviderContainer container,
  NavigatorState? navigator,
  String? payload,
) async {
  await container
      .read(notificationInboxProvider.notifier)
      .markReadByPayload(payload);
  if (navigator == null) return;

  final p = PlannedReminder.parsePayload(payload);

  // Pengingat utang/piutang → buka detailnya.
  if (p != null && p.recurringId.startsWith(debtReminderPrefix)) {
    final id = p.recurringId.substring(debtReminderPrefix.length);
    final exists = container.read(debtsProvider).any((d) => d.id == id);
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            exists ? DebtDetailPage(debtId: id) : const NotificationsPage(),
      ),
    );
    return;
  }
  final recurring = p == null
      ? null
      : container
            .read(recurringProvider)
            .where((r) => r.id == p.recurringId)
            .firstOrNull;
  final recorded =
      p != null &&
      recurring != null &&
      recurring.isRecordedIn(container.read(transactionsProvider), p.dueDate);

  if (p != null && recurring != null && !recorded) {
    await navigator.push(
      MaterialPageRoute<bool>(
        builder: (_) => TransactionFormPage(
          month: p.dueDate.firstOfMonth,
          recurring: recurring,
          occurrenceDate: p.dueDate,
        ),
      ),
    );
  } else {
    await navigator.push(
      MaterialPageRoute<void>(builder: (_) => const NotificationsPage()),
    );
  }
}
