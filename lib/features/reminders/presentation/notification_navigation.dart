import 'package:flutter/material.dart';
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
  final recurring = p == null
      ? null
      : container
            .read(recurringProvider)
            .where((r) => r.id == p.recurringId)
            .firstOrNull;
  final recorded =
      p != null &&
      container
          .read(transactionsProvider)
          .any(
            (t) =>
                t.recurringId == p.recurringId &&
                t.date.isSameMonthAs(p.dueDate),
          );

  if (p != null && recurring != null && !recorded) {
    await navigator.push(
      MaterialPageRoute<bool>(
        builder: (_) => TransactionFormPage(
          month: p.dueDate.firstOfMonth,
          recurring: recurring,
        ),
      ),
    );
  } else {
    await navigator.push(
      MaterialPageRoute<void>(builder: (_) => const NotificationsPage()),
    );
  }
}
